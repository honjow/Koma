const { DatabaseSync, backup } = require('node:sqlite')
const fs = require('node:fs'), os = require('node:os'), path = require('node:path')

function createRdbPort(databasePath = ':memory:') {
  const databases = new Map()
  const ports = new Map()
  const restoredDirectories = []
  let beforeCommit
  let commits = 0
  function forDirectory(filesDir, storagePath = databasePath) {
    if (ports.has(filesDir)) return ports.get(filesDir)
    let db = new DatabaseSync(storagePath)
    databases.set(filesDir, db)
    const store = {
      get version() { return db.prepare('PRAGMA user_version').get().user_version },
      set version(value) { db.exec('PRAGMA user_version = ' + value) },
      executeSync: (sql, args = []) => db.prepare(sql).run(...args),
      execute: async (sql, args) => store.executeSync(sql, args),
      async close() {},
      backup: destination => backup(db, destination),
      async restore(source) {
        const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'koma-rdb-restore-'))
        restoredDirectories.push(directory)
        const destination = path.join(directory, 'Koma.db')
        fs.copyFileSync(source, destination)
        db.close()
        db = new DatabaseSync(destination)
        databases.set(filesDir, db)
      },
      querySqlSync(sql, args = []) {
        const statement = db.prepare(sql)
        statement.setReturnArrays(true)
        const rows = statement.all(...args)
        let index = -1
        return {
          columnCount: rows[0]?.length ?? 0,
          goToNextRow: () => ++index < rows.length,
          getValue: column => rows[index][column],
          getString: column => rows[index][column],
          getLong: column => rows[index][column],
          getDouble: column => rows[index][column],
          getCurrentRowData: () => rows[index].slice(),
          isColumnNull: column => rows[index][column] === null,
          close() {},
        }
      },
      querySql: async (sql, args) => store.querySqlSync(sql, args),
      beginTransaction: () => db.exec('BEGIN'),
      commit() {
        if (beforeCommit) beforeCommit(db)
        db.exec('COMMIT')
        commits += 1
      },
      rollBack: () => db.exec('ROLLBACK'),
      async createTransaction() {
        store.beginTransaction()
        return { execute: store.execute, querySql: store.querySql, commit: store.commit, rollback: store.rollBack }
      },
    }
    ports.set(filesDir, store)
    return store
  }
  return {
    relationalStore: {
      getRdbStore: async (context, config) => config.name === 'koma-user-data.db'
        ? forDirectory(context.filesDir + '/previous', context.databaseDir
          ? context.databaseDir + '/rdb/' + config.name : ':memory:')
        : forDirectory(context.filesDir),
      SecurityLevel: { S3: 3 },
      TransactionType: { IMMEDIATE: 1 },
      SyncMode: { SYNC_MODE_TIME_FIRST: 6 },
      Progress: { SYNC_FINISH: 2 },
      ProgressCode: { SUCCESS: 0, UNKNOWN_ERROR: 1 },
    },
    readReaderPreferences(filesDir) {
      const db = databases.get(filesDir)
      return db.prepare("SELECT 'readerGlobal' AS domain, * FROM reader_preferences").all()
        .concat(db.prepare("SELECT 'readerShared' AS domain, * FROM reader_shared_preferences").all())
        .concat(db.prepare("SELECT 'bookPreferences' AS domain, * FROM book_preferences ORDER BY comic_id").all())
        .concat(db.prepare("SELECT 'seriesModeOverrides' AS domain, comic_id, page_mode, reading_direction " +
          'FROM book_reader_modes_all ORDER BY comic_id').all())
    },
    beforeCommit: callback => { beforeCommit = callback },
    failNextCommit(message = 'simulated interrupted write') {
      beforeCommit = () => {
        beforeCommit = undefined
        throw new Error(message)
      }
    },
    get commits() { return commits },
    close() {
      for (const database of databases.values()) database.close()
      for (const directory of restoredDirectories) fs.rmSync(directory, { recursive: true, force: true })
    },
  }
}

module.exports = { createRdbPort }

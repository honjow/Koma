const { DatabaseSync } = require('node:sqlite')

function createRdbPort() {
  const databases = new Map()
  const ports = new Map()
  let beforeCommit
  let commits = 0
  function forDirectory(filesDir) {
    if (ports.has(filesDir)) return ports.get(filesDir)
    const db = new DatabaseSync(':memory:')
    databases.set(filesDir, db)
    const store = {
      version: 0,
      executeSync: (sql, args = []) => db.prepare(sql).run(...args),
      execute: async (sql, args) => store.executeSync(sql, args),
      querySqlSync(sql, args = []) {
        const rows = db.prepare(sql).all(...args).map(row => Object.values(row))
        let index = -1
        return {
          goToNextRow: () => ++index < rows.length,
          getString: column => rows[index][column],
          getLong: column => rows[index][column],
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
        return { execute: store.execute, commit: store.commit, rollback: store.rollBack }
      },
    }
    ports.set(filesDir, store)
    return store
  }
  return {
    relationalStore: { getRdbStore: async context => forDirectory(context.filesDir), SecurityLevel: { S3: 3 } },
    readRows: filesDir => databases.get(filesDir).prepare(
      'SELECT domain, record_key, value FROM user_keyed_records ORDER BY domain, record_key').all(),
    beforeCommit: callback => { beforeCommit = callback },
    failNextCommit(message = 'simulated interrupted write') {
      beforeCommit = () => {
        beforeCommit = undefined
        throw new Error(message)
      }
    },
    get commits() { return commits },
    close() { for (const database of databases.values()) database.close() },
  }
}

module.exports = { createRdbPort }

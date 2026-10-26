// Ported from NextE; Koma owns processing preferences, model files and cache.
/**
 * Count + byte-size of one cache category, returned by each cache service's stat() for the
 * storage/cache settings page.
 */
export class CacheStat {
  count: number = 0
  bytes: number = 0
}

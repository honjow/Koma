// Adapted from NextE59a7a679. Koma owns configuration, credentials and files.
/**
 * Count + byte-size of one cache category, returned by each cache service's stat() for the
 * storage/cache settings page.
 */
export class CacheStat {
  count: number = 0
  bytes: number = 0
}

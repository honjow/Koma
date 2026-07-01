import { InstalledSourcePackage } from './SourceRuntimeAppRegistry'
import { SourceIndexEntry } from './SourceIndexService'
import { AppStrings } from '../i18n/AppStrings'

export interface SourcePackageTrustSummary {
  provenanceLabel: string
  verificationLabel: string
  identityLabel: string
  capabilitySummaryLabel: string
  boundaryNotice: string
}

function t(name: string): string {
  return AppStrings.get(name)
}

export function sourcePackageTrustBoundaryNotice(): string {
  return t('source_pkg_boundary_notice')
}

export function installedSourceTrustSummary(source: InstalledSourcePackage, capabilitySummary: string): SourcePackageTrustSummary {
  return {
    provenanceLabel: source.status === 'imported' ? t('source_pkg_provenance_imported') : t('source_pkg_provenance_staged'),
    verificationLabel: t('source_pkg_verification_unsigned'),
    identityLabel: t('source_pkg_label_package_id') + source.id + ' · ' + t('source_pkg_label_version') + source.version,
    capabilitySummaryLabel: t('source_pkg_capability_summary_prefix') + capabilitySummary,
    boundaryNotice: sourcePackageTrustBoundaryNotice(),
  }
}

export function sourceIndexCandidateTrustSummary(entry: SourceIndexEntry, isUpdateCandidate: boolean): SourcePackageTrustSummary {
  const version = entry.version.length > 0 ? entry.version : 'unknown'
  return {
    provenanceLabel: isUpdateCandidate ? t('source_pkg_provenance_index_update') : t('source_pkg_provenance_index'),
    verificationLabel: t('source_pkg_verification_unsigned'),
    identityLabel: t('source_pkg_label_package_id') + entry.id + ' · ' + t('source_pkg_label_version') + version,
    capabilitySummaryLabel: t('source_pkg_capability_summary_pending'),
    boundaryNotice: sourcePackageTrustBoundaryNotice(),
  }
}

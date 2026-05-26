import { InstalledSourcePackage } from './SourceRuntimeAppRegistry'
import { SourceIndexEntry } from './SourceIndexService'

export interface SourcePackageTrustSummary {
  provenanceLabel: string
  verificationLabel: string
  identityLabel: string
  capabilitySummaryLabel: string
  boundaryNotice: string
}

export const SOURCE_PACKAGE_TRUST_BOUNDARY_NOTICE: string = 'Koma 不提供默认公开源或预置源列表；源包来自用户导入或用户配置的索引地址。'

export function installedSourceTrustSummary(source: InstalledSourcePackage, capabilitySummary: string): SourcePackageTrustSummary {
  return {
    provenanceLabel: source.status === 'imported' ? '用户导入' : '用户导入（未持久化）',
    verificationLabel: '未验证签名',
    identityLabel: '包 ID：' + source.id + ' · 版本：' + source.version,
    capabilitySummaryLabel: '能力摘要（manifest 派生）：' + capabilitySummary,
    boundaryNotice: SOURCE_PACKAGE_TRUST_BOUNDARY_NOTICE,
  }
}

export function sourceIndexCandidateTrustSummary(entry: SourceIndexEntry, isUpdateCandidate: boolean): SourcePackageTrustSummary {
  const version = entry.version.length > 0 ? entry.version : 'unknown'
  return {
    provenanceLabel: isUpdateCandidate ? '用户配置索引更新候选' : '用户配置索引候选',
    verificationLabel: '未验证签名',
    identityLabel: '包 ID：' + entry.id + ' · 版本：' + version,
    capabilitySummaryLabel: '能力摘要（manifest 派生）：安装校验后显示',
    boundaryNotice: SOURCE_PACKAGE_TRUST_BOUNDARY_NOTICE,
  }
}

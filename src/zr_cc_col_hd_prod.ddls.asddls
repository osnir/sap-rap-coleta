@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Coleta Head Produto'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CC_COL_HD_PROD 
  as select from zcc_col_hd_prod
  association to parent ZR_CC_COLETA_HEAD as _Head
    on  $projection.TableName = _Head.TableName
    and $projection.Period    = _Head.Period
{
    key tablename    as TableName,
    key period       as Period,
    key product_code as ProductCode,
    @Semantics.user.createdBy: true
    created_by   as CreatedBy,
    @Semantics.systemDateTime.createdAt: true
    created_at   as CreatedAt,
    @Semantics.user.localInstanceLastChangedBy: true
    last_changed_by as LastChangedBy,
    @Semantics.systemDateTime.lastChangedAt: true
    last_changed_at as LastChangedAt,
    @Semantics.systemDateTime.localInstanceLastChangedAt: true
    local_last_changed_at as LocalLastChangedAt,

    _Head
    
}

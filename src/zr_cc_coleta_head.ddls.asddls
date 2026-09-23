@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Coleta Head'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_CC_COLETA_HEAD 
as select from zcc_coleta_head
composition [0..*] of ZR_CC_COL_HD_PROD as _Products
{
    key tablename   as TableName,
    key period      as Period,
    trig_type   as TrigType,
    status_proc as StatusProc,
    @Semantics.user.createdBy: true
    created_by  as CreatedBy,
    @Semantics.systemDateTime.createdAt: true
    created_at  as CreatedAt,
    @Semantics.user.localInstanceLastChangedBy: true
    last_changed_by as LastChangedBy,
    @Semantics.systemDateTime.lastChangedAt: true
    last_changed_at as LastChangedAt,
    @Semantics.systemDateTime.localInstanceLastChangedAt: true
    local_last_changed_at as LocalLastChangedAt,

    _Products    
}

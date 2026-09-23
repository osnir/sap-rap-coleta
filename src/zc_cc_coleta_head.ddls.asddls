@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption Coleta Head'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_CC_COLETA_HEAD
  provider contract transactional_query 
  as projection on ZR_CC_COLETA_HEAD
{
    key TableName,
    key Period,
    TrigType,
    StatusProc,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    
    /* Associations */
    _Products : redirected to composition child ZC_CC_COL_HD_PROD
}

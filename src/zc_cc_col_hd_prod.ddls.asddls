@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption Coleta Head Produto'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZC_CC_COL_HD_PROD 
  as projection on ZR_CC_COL_HD_PROD
{
    key TableName,
    key Period,
    key ProductCode,
    CreatedBy,
    CreatedAt,
    LastChangedBy,
    LastChangedAt,
    LocalLastChangedAt,
    
    /* Associations */
    _Head : redirected to parent ZC_CC_COLETA_HEAD
}

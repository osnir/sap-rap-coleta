CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES ty_flag TYPE c LENGTH 1.   " C = criar, U = alterar, D = excluir

    TYPES: BEGIN OF ty_head_buf.
             INCLUDE TYPE zcc_coleta_head.
    TYPES:   flag TYPE ty_flag,
           END OF ty_head_buf,
           BEGIN OF ty_prod_buf.
             INCLUDE TYPE zcc_col_hd_prod.
    TYPES: flag TYPE ty_flag,
           END OF ty_prod_buf.

    TYPES tt_prod TYPE STANDARD TABLE OF zcc_col_hd_prod WITH EMPTY KEY.

    CLASS-DATA:
      mt_head TYPE SORTED TABLE OF ty_head_buf WITH UNIQUE KEY tablename period,
      mt_prod TYPE SORTED TABLE OF ty_prod_buf WITH UNIQUE KEY tablename period product_code.

    CLASS-METHODS now
      RETURNING VALUE(rv_ts) TYPE timestampl.

    CLASS-METHODS get_head
      IMPORTING iv_tablename   TYPE zcc_coleta_head-tablename
                iv_period      TYPE zcc_coleta_head-period
      RETURNING VALUE(rs_head) TYPE zcc_coleta_head.

    CLASS-METHODS get_product
      IMPORTING iv_tablename   TYPE zcc_col_hd_prod-tablename
                iv_period      TYPE zcc_col_hd_prod-period
                iv_product     TYPE zcc_col_hd_prod-product_code
      RETURNING VALUE(rs_prod) TYPE zcc_col_hd_prod.

    CLASS-METHODS get_products
      IMPORTING iv_tablename    TYPE zcc_col_hd_prod-tablename
                iv_period       TYPE zcc_col_hd_prod-period
      RETURNING VALUE(rt_prods) TYPE tt_prod.

    CLASS-METHODS put_head
      IMPORTING is_head TYPE zcc_coleta_head
                iv_flag TYPE ty_flag.

    CLASS-METHODS put_prod
      IMPORTING is_prod TYPE zcc_col_hd_prod
                iv_flag TYPE ty_flag.

    CLASS-METHODS clear.
ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.

  METHOD now.
    GET TIME STAMP FIELD rv_ts.
  ENDMETHOD.

  METHOD get_head.
    READ TABLE mt_head INTO DATA(ls_buf)
         WITH TABLE KEY tablename = iv_tablename period = iv_period.
    IF sy-subrc = 0.
      IF ls_buf-flag <> 'D'.
        rs_head = CORRESPONDING #( ls_buf ).
      ENDIF.
      RETURN.
    ENDIF.
    SELECT SINGLE * FROM zcc_coleta_head
      WHERE tablename = @iv_tablename AND period = @iv_period
      INTO @rs_head.
  ENDMETHOD.

  METHOD get_product.
    READ TABLE mt_prod INTO DATA(ls_buf)
         WITH TABLE KEY tablename = iv_tablename period = iv_period product_code = iv_product.
    IF sy-subrc = 0.
      IF ls_buf-flag <> 'D'.
        rs_prod = CORRESPONDING #( ls_buf ).
      ENDIF.
      RETURN.
    ENDIF.
    SELECT SINGLE * FROM zcc_col_hd_prod
      WHERE tablename = @iv_tablename AND period = @iv_period AND product_code = @iv_product
      INTO @rs_prod.
  ENDMETHOD.

  METHOD get_products.
    " Registros do banco que não foram tocados no buffer
    SELECT * FROM zcc_col_hd_prod
      WHERE tablename = @iv_tablename AND period = @iv_period
      INTO TABLE @DATA(lt_db).
    LOOP AT lt_db INTO DATA(ls_db).
      IF NOT line_exists( mt_prod[ tablename    = ls_db-tablename
                                   period       = ls_db-period
                                   product_code = ls_db-product_code ] ).
        APPEND ls_db TO rt_prods.
      ENDIF.
    ENDLOOP.
    " Registros do buffer (exceto os marcados para exclusão)
    LOOP AT mt_prod INTO DATA(ls_buf)
         WHERE tablename = iv_tablename AND period = iv_period AND flag <> 'D'.
      APPEND CORRESPONDING #( ls_buf ) TO rt_prods.
    ENDLOOP.
  ENDMETHOD.

  METHOD put_head.
    READ TABLE mt_head INTO DATA(ls_buf)
         WITH TABLE KEY tablename = is_head-tablename period = is_head-period.
    IF sy-subrc <> 0.
      ls_buf = CORRESPONDING #( is_head ).
      ls_buf-flag = iv_flag.
      INSERT ls_buf INTO TABLE mt_head.
      RETURN.
    ENDIF.

    CASE iv_flag.
      WHEN 'D'.
        IF ls_buf-flag = 'C'.                 " criado e excluído na mesma LUW
          DELETE TABLE mt_head FROM ls_buf.
        ELSE.
          ls_buf-flag = 'D'.
          MODIFY TABLE mt_head FROM ls_buf.
        ENDIF.
      WHEN 'U'.
        DATA(lv_old) = ls_buf-flag.
        ls_buf = CORRESPONDING #( is_head ).
        ls_buf-flag = COND #( WHEN lv_old = 'C' THEN 'C' ELSE 'U' ).
        MODIFY TABLE mt_head FROM ls_buf.
      WHEN 'C'.                               " recriado após exclusão
        ls_buf = CORRESPONDING #( is_head ).
        ls_buf-flag = 'U'.
        MODIFY TABLE mt_head FROM ls_buf.
    ENDCASE.
  ENDMETHOD.

  METHOD put_prod.
    READ TABLE mt_prod INTO DATA(ls_buf)
         WITH TABLE KEY tablename    = is_prod-tablename
                        period       = is_prod-period
                        product_code = is_prod-product_code.
    IF sy-subrc <> 0.
      ls_buf = CORRESPONDING #( is_prod ).
      ls_buf-flag = iv_flag.
      INSERT ls_buf INTO TABLE mt_prod.
      RETURN.
    ENDIF.

    CASE iv_flag.
      WHEN 'D'.
        IF ls_buf-flag = 'C'.
          DELETE TABLE mt_prod FROM ls_buf.
        ELSE.
          ls_buf-flag = 'D'.
          MODIFY TABLE mt_prod FROM ls_buf.
        ENDIF.
      WHEN 'C'.                               " recriado após exclusão
        ls_buf = CORRESPONDING #( is_prod ).
        ls_buf-flag = 'U'.
        MODIFY TABLE mt_prod FROM ls_buf.
    ENDCASE.
  ENDMETHOD.

  METHOD clear.
    CLEAR: mt_head, mt_prod.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_head DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Head RESULT result.

    METHODS create FOR MODIFY
      IMPORTING entities FOR CREATE Head.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE Head.

    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE Head.

    METHODS read FOR READ
      IMPORTING keys FOR READ Head RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK Head.

    METHODS rba_Products FOR READ
      IMPORTING keys_rba FOR READ Head\_Products FULL result_requested
      RESULT    result LINK association_links.

    METHODS cba_Products FOR MODIFY
      IMPORTING entities_cba FOR CREATE Head\_Products.
ENDCLASS.

CLASS lhc_head IMPLEMENTATION.

  METHOD get_instance_authorizations.
    result = VALUE #( FOR key IN keys
                      ( %tky              = key-%tky
                        %update           = if_abap_behv=>auth-allowed
                        %delete           = if_abap_behv=>auth-allowed ) ).
  ENDMETHOD.

  METHOD create.
    DATA(lv_ts) = lcl_buffer=>now( ).

    LOOP AT entities INTO DATA(entity).
      IF entity-TableName IS INITIAL OR entity-Period IS INITIAL.
        APPEND VALUE #( %cid = entity-%cid %key = entity-%key ) TO failed-head.
        APPEND VALUE #( %cid = entity-%cid %key = entity-%key
                        %msg = new_message_with_text( text = 'TableName e Period são obrigatórios' ) )
               TO reported-head.
        CONTINUE.
      ENDIF.

      IF lcl_buffer=>get_head( iv_tablename = entity-TableName
                               iv_period    = entity-Period ) IS NOT INITIAL.
        APPEND VALUE #( %cid = entity-%cid %key = entity-%key ) TO failed-head.
        APPEND VALUE #( %cid = entity-%cid %key = entity-%key
                        %msg = new_message_with_text( text = |Coleta { entity-TableName }/{ entity-Period } já existe| ) )
               TO reported-head.
        CONTINUE.
      ENDIF.

      DATA(ls_head) = CORRESPONDING zcc_coleta_head( entity MAPPING FROM ENTITY ).
      ls_head-created_by            = sy-uname.
      ls_head-last_changed_by       = sy-uname.
      ls_head-created_at            = lv_ts.
      ls_head-last_changed_at       = lv_ts.
      ls_head-local_last_changed_at = lv_ts.

      lcl_buffer=>put_head( is_head = ls_head iv_flag = 'C' ).

      APPEND VALUE #( %cid = entity-%cid %key = entity-%key ) TO mapped-head.
    ENDLOOP.
  ENDMETHOD.

  METHOD update.
    DATA(lv_ts) = lcl_buffer=>now( ).

    LOOP AT entities INTO DATA(entity).
      DATA(ls_head) = lcl_buffer=>get_head( iv_tablename = entity-TableName
                                            iv_period    = entity-Period ).
      IF ls_head IS INITIAL.
        APPEND VALUE #( %tky = entity-%tky ) TO failed-head.
        APPEND VALUE #( %tky = entity-%tky
                        %msg = new_message_with_text( text = 'Coleta não encontrada' ) ) TO reported-head.
        CONTINUE.
      ENDIF.

      IF entity-%control-TrigType = if_abap_behv=>mk-on.
        ls_head-trig_type = entity-TrigType.
      ENDIF.
      IF entity-%control-StatusProc = if_abap_behv=>mk-on.
        ls_head-status_proc = entity-StatusProc.
      ENDIF.

      ls_head-last_changed_by       = sy-uname.
      ls_head-last_changed_at       = lv_ts.
      ls_head-local_last_changed_at = lv_ts.

      lcl_buffer=>put_head( is_head = ls_head iv_flag = 'U' ).
    ENDLOOP.
  ENDMETHOD.

  METHOD delete.
    LOOP AT keys INTO DATA(key).
      DATA(ls_head) = lcl_buffer=>get_head( iv_tablename = key-TableName
                                            iv_period    = key-Period ).
      IF ls_head IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-head.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( text = 'Coleta não encontrada' ) ) TO reported-head.
        CONTINUE.
      ENDIF.

      " >>> Delete em cascata: marca todos os produtos filhos para exclusão
      DATA(lt_prods) = lcl_buffer=>get_products( iv_tablename = key-TableName
                                                 iv_period    = key-Period ).
      LOOP AT lt_prods INTO DATA(ls_prod).
        lcl_buffer=>put_prod( is_prod = ls_prod iv_flag = 'D' ).
      ENDLOOP.

      lcl_buffer=>put_head( is_head = ls_head iv_flag = 'D' ).
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys INTO DATA(key).
      DATA(ls_head) = lcl_buffer=>get_head( iv_tablename = key-TableName
                                            iv_period    = key-Period ).
      IF ls_head IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-head.
        CONTINUE.
      ENDIF.
      APPEND CORRESPONDING #( ls_head MAPPING TO ENTITY ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD lock.
    TRY.
        DATA(lo_lock) = cl_abap_lock_object_factory=>get_instance( iv_name = 'EZCC_COLETA_HEAD' ).
      CATCH cx_abap_lock_failure.
        RETURN.
    ENDTRY.

    LOOP AT keys INTO DATA(key).
      TRY.
          lo_lock->enqueue(
            it_parameter = VALUE #( ( name = 'TABLENAME' value = REF #( key-TableName ) )
                                    ( name = 'PERIOD'    value = REF #( key-Period ) ) ) ).

        CATCH cx_abap_foreign_lock INTO DATA(lx_foreign).
          APPEND VALUE #( TableName = key-TableName
                          Period    = key-Period ) TO failed-head.
          APPEND VALUE #( TableName = key-TableName
                          Period    = key-Period
                          %msg      = new_message_with_text(
                                        text = |Coleta bloqueada pelo usuário { lx_foreign->user_name }| ) )
                 TO reported-head.

        CATCH cx_abap_lock_failure.
          APPEND VALUE #( TableName = key-TableName
                          Period    = key-Period ) TO failed-head.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_Products.
    LOOP AT keys_rba INTO DATA(key).
      IF lcl_buffer=>get_head( iv_tablename = key-TableName
                               iv_period    = key-Period ) IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-head.
        CONTINUE.
      ENDIF.

      DATA(lt_prods) = lcl_buffer=>get_products( iv_tablename = key-TableName
                                                 iv_period    = key-Period ).
      LOOP AT lt_prods INTO DATA(ls_prod).
        APPEND VALUE #( source-%tky        = key-%tky
                        target-TableName   = ls_prod-tablename
                        target-Period      = ls_prod-period
                        target-ProductCode = ls_prod-product_code ) TO association_links.
        IF result_requested = abap_true.
          APPEND CORRESPONDING #( ls_prod MAPPING TO ENTITY ) TO result.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD cba_Products.
    DATA(lv_ts) = lcl_buffer=>now( ).

    LOOP AT entities_cba INTO DATA(entity_cba).
      " O pai precisa existir (no banco ou criado nesta mesma LUW)
      IF lcl_buffer=>get_head( iv_tablename = entity_cba-TableName
                               iv_period    = entity_cba-Period ) IS INITIAL.
        LOOP AT entity_cba-%target INTO DATA(ls_target_err).
          APPEND VALUE #( %cid = ls_target_err-%cid ) TO failed-product.
        ENDLOOP.
        APPEND VALUE #( %tky = entity_cba-%tky
                        %msg = new_message_with_text( text = 'Coleta pai não encontrada' ) ) TO reported-head.
        CONTINUE.
      ENDIF.

      DATA(lt_existing) = lcl_buffer=>get_products( iv_tablename = entity_cba-TableName
                                                    iv_period    = entity_cba-Period ).

      LOOP AT entity_cba-%target INTO DATA(ls_target).
        IF ls_target-ProductCode IS INITIAL.
          APPEND VALUE #( %cid = ls_target-%cid ) TO failed-product.
          APPEND VALUE #( %cid = ls_target-%cid
                          %msg = new_message_with_text( text = 'Código do produto é obrigatório' ) )
                 TO reported-product.
          CONTINUE.
        ENDIF.

        IF line_exists( lt_existing[ product_code = ls_target-ProductCode ] ).
          APPEND VALUE #( %cid = ls_target-%cid ) TO failed-product.
          APPEND VALUE #( %cid = ls_target-%cid
                          %msg = new_message_with_text( text = |Produto { ls_target-ProductCode } já existe na coleta| ) )
                 TO reported-product.
          CONTINUE.
        ENDIF.

        " Chaves herdadas do pai
        DATA(ls_prod) = VALUE zcc_col_hd_prod(
                          tablename             = entity_cba-TableName
                          period                = entity_cba-Period
                          product_code          = ls_target-ProductCode
                          created_by            = sy-uname
                          created_at            = lv_ts
                          last_changed_by       = sy-uname
                          last_changed_at       = lv_ts
                          local_last_changed_at = lv_ts ).

        lcl_buffer=>put_prod( is_prod = ls_prod iv_flag = 'C' ).
        APPEND ls_prod TO lt_existing.

        APPEND VALUE #( %cid        = ls_target-%cid
                        TableName   = ls_prod-tablename
                        Period      = ls_prod-period
                        ProductCode = ls_prod-product_code ) TO mapped-product.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_product DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS delete FOR MODIFY
      IMPORTING keys FOR DELETE Product.

    METHODS read FOR READ
      IMPORTING keys FOR READ Product RESULT result.

    METHODS rba_Head FOR READ
      IMPORTING keys_rba FOR READ Product\_Head FULL result_requested
      RESULT    result LINK association_links.
ENDCLASS.

CLASS lhc_product IMPLEMENTATION.

  METHOD delete.
    LOOP AT keys INTO DATA(key).
      DATA(ls_prod) = lcl_buffer=>get_product( iv_tablename = key-TableName
                                               iv_period    = key-Period
                                               iv_product   = key-ProductCode ).
      IF ls_prod IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-product.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text( text = 'Produto não encontrado' ) ) TO reported-product.
        CONTINUE.
      ENDIF.
      lcl_buffer=>put_prod( is_prod = ls_prod iv_flag = 'D' ).
    ENDLOOP.
  ENDMETHOD.

  METHOD read.
    LOOP AT keys INTO DATA(key).
      DATA(ls_prod) = lcl_buffer=>get_product( iv_tablename = key-TableName
                                               iv_period    = key-Period
                                               iv_product   = key-ProductCode ).
      IF ls_prod IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-product.
        CONTINUE.
      ENDIF.
      APPEND CORRESPONDING #( ls_prod MAPPING TO ENTITY ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD rba_Head.
    LOOP AT keys_rba INTO DATA(key).
      DATA(ls_head) = lcl_buffer=>get_head( iv_tablename = key-TableName
                                            iv_period    = key-Period ).
      IF ls_head IS INITIAL.
        APPEND VALUE #( %tky = key-%tky ) TO failed-product.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( source-%tky      = key-%tky
                      target-TableName = ls_head-tablename
                      target-Period    = ls_head-period ) TO association_links.

      IF result_requested = abap_true.
        APPEND CORRESPONDING #( ls_head MAPPING TO ENTITY ) TO result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lsc_zr_cc_coleta_head DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS finalize          REDEFINITION.
    METHODS check_before_save REDEFINITION.
    METHODS save              REDEFINITION.
    METHODS cleanup           REDEFINITION.
    METHODS cleanup_finalize  REDEFINITION.
ENDCLASS.

CLASS lsc_zr_cc_coleta_head IMPLEMENTATION.

  METHOD finalize.
  ENDMETHOD.

  METHOD check_before_save.
  ENDMETHOD.

  METHOD save.
    DATA: lt_head_ins TYPE STANDARD TABLE OF zcc_coleta_head,
          lt_head_upd TYPE STANDARD TABLE OF zcc_coleta_head,
          lt_head_del TYPE STANDARD TABLE OF zcc_coleta_head,
          lt_prod_ins TYPE STANDARD TABLE OF zcc_col_hd_prod,
          lt_prod_upd TYPE STANDARD TABLE OF zcc_col_hd_prod,
          lt_prod_del TYPE STANDARD TABLE OF zcc_col_hd_prod.

    LOOP AT lcl_buffer=>mt_head INTO DATA(ls_h).
      CASE ls_h-flag.
        WHEN 'C'. APPEND CORRESPONDING #( ls_h ) TO lt_head_ins.
        WHEN 'U'. APPEND CORRESPONDING #( ls_h ) TO lt_head_upd.
        WHEN 'D'. APPEND CORRESPONDING #( ls_h ) TO lt_head_del.
      ENDCASE.
    ENDLOOP.

    LOOP AT lcl_buffer=>mt_prod INTO DATA(ls_p).
      CASE ls_p-flag.
        WHEN 'C'. APPEND CORRESPONDING #( ls_p ) TO lt_prod_ins.
        WHEN 'U'. APPEND CORRESPONDING #( ls_p ) TO lt_prod_upd.
        WHEN 'D'. APPEND CORRESPONDING #( ls_p ) TO lt_prod_del.
      ENDCASE.
    ENDLOOP.

    " Exclusão: filhos primeiro, depois o pai
    IF lt_prod_del IS NOT INITIAL.
      DELETE zcc_col_hd_prod FROM TABLE @lt_prod_del.
    ENDIF.
    IF lt_head_del IS NOT INITIAL.
      DELETE zcc_coleta_head FROM TABLE @lt_head_del.
    ENDIF.

    " Inclusão/alteração: pai primeiro, depois os filhos
    IF lt_head_ins IS NOT INITIAL.
      INSERT zcc_coleta_head FROM TABLE @lt_head_ins.
    ENDIF.
    IF lt_head_upd IS NOT INITIAL.
      UPDATE zcc_coleta_head FROM TABLE @lt_head_upd.
    ENDIF.
    IF lt_prod_ins IS NOT INITIAL.
      INSERT zcc_col_hd_prod FROM TABLE @lt_prod_ins.
    ENDIF.
    IF lt_prod_upd IS NOT INITIAL.
      UPDATE zcc_col_hd_prod FROM TABLE @lt_prod_upd.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup.
    lcl_buffer=>clear( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
    lcl_buffer=>clear( ).
  ENDMETHOD.

ENDCLASS.

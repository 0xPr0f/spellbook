{{ config(
    alias = 'nft_mints',
    partition_by = ['block_date'],
    materialized = 'incremental',
    file_format = 'delta',
    incremental_strategy = 'merge',
    unique_key = ['block_number', 'tx_hash', 'nft_contract_address', 'tokenId'],
    post_hook='{{ expose_spells(\'["optimism"]\',
                                "project",
                                "galxe",
                                \'["msilb7"]\') }}'
    )
}}
--SELECT MIN(block_time) FROM optimism.transactions where to = 0x2e42f214467f647Fe687Fd9a2bf3BAdDFA737465
{% set project_start_date = '2022-07-17' %}
{% set spacestation = '0x2e42f214467f647fe687fd9a2bf3baddfa737465' %}

SELECT
    DATE_TRUNC('day',block_time) AS block_date,
    block_time,
    block_number,
    t.from as tx_from,
    t.to as tx_to,
    t.hash AS tx_hash,
    substring(t.data,1,10) AS tx_method_id,
    tfer.to AS token_transfer_to,
    tfer.contract_address AS nft_contract_address,
    tfer.tokenId

FROM
    {{source('optimism','transactions')}} t
INNER JOIN {{source('erc721_optimism','evt_transfer')}} tfer 
    ON t.hash = tfer.evt_tx_hash
    AND t.block_number = tfer.evt_block_number
    AND t.from = '0x0000000000000000000000000000000000000000' --mint
    {% if is_incremental() %}
    AND tfer.evt_block_time >= date_trunc('day', now() - interval '1 week')
    {% endif %}

WHERE success = true
    AND to = '{{spacestation}}'
AND block_time >= cast( '{{project_start_date}}' as timestamp)
{% if is_incremental() %}
AND block_time >= date_trunc('day', now() - interval '1 week')
{% endif %}
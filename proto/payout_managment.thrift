include "base.thrift"
include "domain.thrift"
include "msgpack.thrift"

namespace java com.rbkmoney.payout.manager
namespace erlang payout_manager

typedef base.ID PayoutID

struct Payout {
    1: required PayoutID id
    2: required base.Timestamp created_at
    3: required domain.PartyID party_id
    4: required domain.ShopID shop_id
    5: required domain.ContractID contract_id
    6: required PayoutStatus status
    7: required domain.FinalCashFlow cash_flow
    8: required domain.PayoutToolID payout_tool_id
    9: required domain.Amount amount
    10: required domain.Amount fee
    11: required domain.CurrencyRef currency
}

/**
 * Выплата создается в статусе "unpaid", затем может перейти либо в "paid", если
 * банк подтвердил, что принял ее в обработку (считаем, что она выплачена,
 * а она и будет выплачена в 99% случаев), либо в "cancelled", если не получилось
 * доставить выплату до банка.
 *
 * Из статуса "paid" выплата может перейти либо в "confirmed", если есть подтверждение
 * оплаты, либо в "cancelled", если была получена информация о неуспешном переводе.
 *
 * Может случиться так, что уже подтвержденную выплату нужно отменять, и тогда выплата
 * может перейти из статуса "confirmed" в "cancelled".
 */
union PayoutStatus {
    1: PayoutUnpaid unpaid
    2: PayoutPaid paid
    3: PayoutCancelled cancelled
    4: PayoutConfirmed confirmed
}

/* Создается в статусе unpaid */
struct PayoutUnpaid {}

/* Помечается статусом paid, когда удалось отправить в банк */
struct PayoutPaid {}

/**
 * Помечается статусом cancelled, когда не удалось отправить в банк,
 * либо когда полностью откатывается из статуса confirmed с изменением
 * балансов на счетах
 */
struct PayoutCancelled {
    1: required string details
}

/**
 * Помечается статусом confirmed, когда можно менять балансы на счетах,
 * то есть если выплата confirmed, то балансы уже изменены
 */
struct PayoutConfirmed {}

exception PayoutNotFound {}

/* Когда на счете для вывода недостаточно средств */
exception InsufficientFunds {}

/**
* Параметры для создания выплаты
* shop - параметры магазина
* amount - сумма выплаты
**/
struct PayoutParams {
    1: required ShopParams shop_params
    2: required domain.Cash cash
}

struct ShopParams {
    1: required domain.PartyID party_id
    2: required domain.ShopID shop_id
}

service PayoutManagement {

    /**
     * Создать выплату на определенную сумму и платежный инструмент
     */
    Payout CreatePayout (1: PayoutParams payout_params) throws (1: InsufficientFunds ex2, 2: base.InvalidRequest ex3)

    /**
    * Получить выплату по идентификатору
    */
    Payout GetPayout (1: PayoutID payout_id) throws (1: PayoutNotFound ex1)

    /**
     * Подтвердить выплату.
     */
    void ConfirmPayout (1: PayoutID payout_id) throws (1: base.InvalidRequest ex1)

    /**
     * Отменить движения по выплате.
     */
    void CancelPayout (1: PayoutID payout_id, 2: string details) throws (1: base.InvalidRequest ex1)

}

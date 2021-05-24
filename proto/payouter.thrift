include "base.thrift"
include "domain.thrift"
include "msgpack.thrift"

namespace java com.rbkmoney.damsel.payouter
namespace erlang payouter

typedef base.ID PayoutID
typedef list<Event> Events

/**
 * Событие, атомарный фрагмент истории бизнес-объекта, например выплаты
 */
struct Event {

    /**
     * Идентификатор события.
     * Монотонно возрастающее целочисленное значение, таким образом на множестве
     * событий задаётся отношение полного порядка (total order)
     */
    1: required base.EventID id

    /**
     * Время создания события
     */
    2: required base.Timestamp created_at

    /**
     * Идентификатор бизнес-объекта, источника события
     */
    3: required EventSource source

    /**
     * Содержание события, состоящее из списка (возможно пустого)
     * изменений состояния бизнес-объекта, источника события
     */
    4: required EventPayload payload

}

/**
 * Источник события, идентификатор бизнес-объекта, который породил его в
 * процессе выполнения определённого бизнес-процесса
 */
union EventSource {
    /* Идентификатор выплаты, которая породила событие */
    1: PayoutID payout_id
}

/**
 * Один из возможных вариантов содержания события
 */
union EventPayload {
    /* Набор изменений, порождённых выплатой */
    1: list<PayoutChange> payout_changes
}

/**
 * Один из возможных вариантов события, порождённого выплатой
 */
union PayoutChange {
    1: PayoutCreated        payout_created
    2: PayoutStatusChanged  payout_status_changed
}

/**
 * Событие о создании новой выплаты
 */
struct PayoutCreated {
    /* Данные созданной выплаты */
    1: required Payout payout
}

struct Payout {
    1 : required PayoutID id
    2 : required domain.PartyID party_id
    3 : required domain.ShopID shop_id
    9 : required domain.ContractID contract_id
    /* Время формирования платежного поручения, либо выплаты на карту  */
    4 : required base.Timestamp created_at
    5 : required PayoutStatus status
    11: required domain.Amount amount
    12: required domain.Amount fee
    13: required domain.CurrencyRef currency
    6 : required domain.FinalCashFlow payout_flow
    7 : required PayoutType type
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
    2: required string details
}

/**
 * Помечается статусом confirmed, когда можно менять балансы на счетах,
 * то есть если выплата confirmed, то балансы уже изменены
 */
struct PayoutConfirmed {}

/* Типы выплаты */
union PayoutType {
    2: PayoutAccount bank_account
    3: Wallet wallet
    4: NKO nko //TODO
}

struct NKO { //TODO
    1: required string id
}

struct Wallet {
    1: required domain.WalletID wallet_id
}

/* Вывод на расчетный счет */
union PayoutAccount {
    1: RussianPayoutAccount       russian_payout_account
    2: InternationalPayoutAccount international_payout_account
}

struct RussianPayoutAccount {
    1: required domain.RussianBankAccount bank_account
    2: required string inn
    3: required string purpose
    4: required domain.LegalAgreement legal_agreement
}

struct InternationalPayoutAccount {
   1: required domain.InternationalBankAccount bank_account
   2: required domain.InternationalLegalEntity legal_entity
   3: required string purpose
   4: required domain.LegalAgreement legal_agreement
}

/**
 * Событие об изменении статуса выплаты
 */
struct PayoutStatusChanged {
    /* Новый статус выплаты */
    1: required PayoutStatus status
}

exception PayoutNotFound {}

/* Когда на счете для вывода недостаточно средств */
exception InsufficientFunds {}

struct ShopParams {
    1: required domain.PartyID party_id
    2: required domain.ShopID shop_id
}

/**
* Параметры для создания выплаты
* shop - параметры магазина
* amount - сумма выплаты
**/
struct PayoutParams {
    1: required ShopParams shop
    2: required domain.Cash amount
}

service PayoutManagement {

    /**
     * Создать выплату на определенную сумму и платежный инструмент
     */
    Payout CreatePayout (1: PayoutParams params) throws (1: InsufficientFunds ex2, 2: base.InvalidRequest ex3)

    /**
    * Получить выплату по идентификатору
    */
    Payout Get (1: PayoutID payout_id) throws (1: PayoutNotFound ex1)

    /**
     * Подтвердить выплату.
     */
    void ConfirmPayout (1: PayoutID payout_id) throws (1: base.InvalidRequest ex1)

    /**
     * Отменить движения по выплате.
     */
    void CancelPayout (1: PayoutID payout_id, 2: string details) throws (1: base.InvalidRequest ex1)
}

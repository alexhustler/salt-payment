require 'cgi'
require 'net/http'
require 'net/https'
# require 'logger'

# $log = Logger.new('log.txt')
class HttpsCreditCardService
  attr_reader :error_msg
  attr_reader :error_code

  def initialize(*args)
    @market_segment = $market_segment_internet

    # HttpsCreditCardService (merchant, url)
    if args.size == 2
      @merchant = args[0]
      @url = args[1]
    else

      # HttpsCreditCardService (merchantId, api_token, url)
      @merchant_id = args[0]
      @api_token = args[1]
      @url = args[2]
      @merchant = Merchant.new(@merchant_id, @api_token)
    end
  end

  def refund(purchase_id, purchase_order_id, refund_order_id, amount)
    if purchase_order_id == nil
      raise InvalidRequest, 'purchase_order_id is required'
    end

    req = Hash::new

    append_header(req, 'refund')
    append_transaction_id(req, purchase_id)
    append_transaction_order_id(req, purchase_order_id)
    if refund_order_id !=nil
      append_order_id(req, refund_order_id)
    end
    append_amount(req, amount)
    send(req, 'creditcard')
  end

  def single_purchase(order_id, credit_card_specifier, amount, verification_request)
    if credit_card_specifier == nil
      raise InvalidRequest, 'creditcard or storage_token_id is required'
    end
    if order_id == nil
      raise InvalidRequest, 'order_id is required'
    end
    req = Hash::new

    append_header(req, 'singlePurchase')
    append_order_id(req, order_id)
    if credit_card_specifier.is_a?(String)
      append_storage_token_id(req, credit_card_specifier)
    else
      append_credit_card(req, credit_card_specifier)
    end
    append_amount(req, amount)
    append_verification_request(req, verification_request)
    send(req, 'creditcard')
  end

  def installment_purchase(order_id, credit_card, preinstallmentamount, start_date, total_number_installments, verification_request)
    if order_id == nil
      raise InvalidRequest, 'order_id is required'
    end

    if credit_card == nil
      raise InvalidRequest, 'credit_card is required'
    end

    req = Hash::new

    append_header(req, 'installmentPurchase')
    append_order_id(req, order_id)
    append_credit_card(req, credit_card)
    append_amount(req, preinstallmentamount)
    append_start_date(req, start_date)
    append_total_number_installments(req, total_number_installments)
    append_verification_request(req, verification_request)

    send(req, 'creditcard')
  end

  def recurring_purchase(order_id, credit_card_specifier, per_payment_amount, start_date, end_date, schedule, verification_request)
    if order_id == nil
      raise InvalidRequest, 'order_id is required'
    end
    periodic_purchase_info = PeriodicPurchaseInfo.new(nil, nil, schedule, per_payment_amount, order_id, nil, start_date, end_date, nil)

    recurring_purchase_helper(periodic_purchase_info, credit_card_specifier, verification_request)
  end

  def recurring_purchase2(periodic_purchase_info, credit_card_specifier, verification_request)
    if periodic_purchase_info.order_id == nil
      raise InvalidRequest, 'order_id is required'
    end
    recurring_purchase_helper(periodic_purchase_info, credit_card_specifier, verification_request)
  end

  def recurring_purchase_helper(periodic_purchase_info, credit_card_specifier, verification_request)
    if credit_card_specifier == nil
      raise InvalidRequest, 'creditcard or storage_token_id is required'
    end

    req = Hash::new
    append_header(req, 'recurringPurchase')
    append_operation_type(req, 'create')
    append_periodic_purchase_info(req, periodic_purchase_info)
    append_verification_request(req, verification_request)

    if credit_card_specifier.is_a?(String)
      append_storage_token_id(req, credit_card_specifier)
      send(req, 'storage')
    else
      append_credit_card(req, credit_card_specifier)
      send(req, 'creditcard')
    end
  end

  def hold_recurring_purchase(recurring_purchase_id)
    periodic_purchase_info = PeriodicPurchaseInfo.new(recurring_purchase_id, $on_hold, nil, nil, nil, nil, nil, nil, nil)
    update_recurring_purchase_helper(periodic_purchase_info, nil, nil)
  end

  def resume_recurring_purchase(recurring_purchase_id)
    periodic_purchase_info = PeriodicPurchaseInfo.new(recurring_purchase_id, $in_progress, nil, nil, nil, nil, nil, nil, nil)
    update_recurring_purchase_helper(periodic_purchase_info, nil, nil)
  end

  def cancel_recurring_purchase(recurring_purchase_id)
    periodic_purchase_info = PeriodicPurchaseInfo.new(recurring_purchase_id, $cancelled, nil, nil, nil, nil, nil, nil, nil)
    update_recurring_purchase_helper(periodic_purchase_info, nil, nil)
  end

  def query_recurring_purchase(recurring_purchase_id)
    if recurring_purchase_id == nil
      raise InvalidRequest, 'recurring_purchase_id is required'
    end

    req = Hash::new
    append_header(req, 'recurringPurchase')
    append_operation_type(req, 'query')
    append_transaction_id(req, recurring_purchase_id)

    send(req, 'creditcard')
  end

  def update_recurring_purchase(recurring_purchase_id, credit_card_specifier, per_payment_amount, verification_request, state)
    if recurring_purchase_id == nil
      raise InvalidRequest, 'recurring_purchase_id is required'
    end
    periodic_purchase_info = PeriodicPurchaseInfo.new(recurring_purchase_id, state, nil, per_payment_amount, nil, nil, nil, nil, nil)
    update_recurring_purchase_helper(periodic_purchase_info, credit_card_specifier, verification_request)
  end

  def update_recurring_purchase2(periodic_purchase_info, credit_card_specifier, verification_request)
    if periodic_purchase_info.periodic_transaction_id == nil
      raise InvalidRequest, 'recurring_purchase_id is required'
    end
    update_recurring_purchase_helper(periodic_purchase_info, credit_card_specifier, verification_request)
  end

  def update_recurring_purchase_helper(periodic_purchase_info, credit_card_specifier, verification_request)
    req = Hash::new
    append_header(req, 'recurringPurchase')
    append_operation_type(req, 'update')
    append_transaction_id(req, periodic_purchase_info.periodic_transaction_id)
    if verification_request != nil
      append_verification_request(req, verification_request)
    end
    append_periodic_purchase_info(req, periodic_purchase_info)
    if credit_card_specifier !=nil
      if credit_card_specifier.is_a?(String)
        append_storage_token_id(req, credit_card_specifier)
        return send(req, 'storage')
      else
        append_credit_card(req, credit_card_specifier)
      end
    end
    send(req, 'creditcard')
  end

  def verify_credit_card(credit_card_specifier, verification_request)
    if credit_card_specifier == nil
      raise InvalidRequest, 'credit card or storage_token_id is required'
    end

    if verification_request == nil
      raise InvalidRequest, 'verification_request is required'
    end

    req = Hash::new
    append_header(req, 'verifyCreditCard')
    if credit_card_specifier.is_a?(String)
      append_storage_token_id(req, credit_card_specifier)
    else
      append_credit_card(req, credit_card_specifier)
    end
    append_verification_request(req, verification_request)
    send(req, 'creditcard')
  end

  def void_transaction(transaction_id, transaction_order_id)
    if transaction_order_id == nil
      raise InvalidRequest, 'transaction_order_id is required'
    end
    req = Hash::new
    append_header(req, 'void')
    append_transaction_id(req, transaction_id)
    append_transaction_order_id(req, transaction_order_id)
    send(req, 'creditcard')
  end

  def verify_transaction(transaction_id, transaction_order_id)

    if transaction_order_id == nil || transaction_id == nil
      raise InvalidRequest, 'either transaction_id or transaction_order_id is required'
    end

    req = Hash::new
    append_header(req, 'verifyTransaction')
    if transaction_id != nil
      append_transaction_id(req, transaction_id)
    end
    if transaction_order_id != nil
      append_transaction_order_id(req, transaction_order_id)
    end
    send(req, 'creditcard')
  end

  def add_to_storage(storage_token_id, payment_profile)
    if payment_profile == nil
      raise InvalidRequest, 'payment profile is required'
    end

    req = Hash::new

    append_header(req, 'secureStorage')
    append_operation_type(req, 'create')
    append_storage_token_id(req, storage_token_id)
    append_payment_profiles(req, payment_profile)
    send(req, 'storage')
  end

  def delete_from_storage(storage_token_id)
    if storage_token_id == nil
      raise InvalidRequest, 'storage_token_id is required'
    end

    req = Hash::new
    append_header(req, 'secureStorage')
    append_operation_type(req, 'delete')
    append_storage_token_id(req, storage_token_id)
    send(req, 'storage')
  end

  def query_storage(storage_token_id)
    if storage_token_id == nil
      raise InvalidRequest, 'storage_token_id is required'
    end

    req = Hash::new
    append_header(req, 'secureStorage')
    append_operation_type(req, 'query')
    append_storage_token_id(req, storage_token_id)
    send(req, 'storage')
  end

  def update_storage(storage_token_id, payment_profile)
    if storage_token_id == nil
      raise InvalidRequest, 'storage_token_id is required'
    end
    if payment_profile == nil
      raise InvalidRequest, 'payment profile is required'
    end
    req = Hash::new
    append_header(req, 'secureStorage')
    append_operation_type(req, 'update')
    append_storage_token_id(req, storage_token_id)
    append_payment_profiles(req, payment_profile)
    send(req, 'storage')
  end

  def append_amount(req, amount)
    append_param(req, 'amount', amount)
  end

  def append_api_token(req, api_token)
    append_param(req, 'apiToken', api_token)
  end

  def append_credit_card(req, credit_card)
    if credit_card != nil
      append_param(req, 'creditCardNumber', credit_card.get_credit_card_number)
      append_param(req, 'expiryDate', credit_card.get_expiry_date)
      append_param(req, 'cvv2', credit_card.get_cvv2)
      append_param(req, 'street', credit_card.get_street)
      append_param(req, 'zip', credit_card.get_zip)
      append_param(req, 'secureCode', credit_card.get_secure_code)
    end
  end

  def append_header(req, request_code)
    append_param(req, 'requestCode', request_code)
    append_merchant_id(req, @merchant.merchant_id)
    append_api_token(req, @merchant.api_token)
    append_param(req, 'marketSegmentCode', @market_segment)
  end

  def append_operation_type(req, type)
    if type!= nil
      append_param(req, 'operationCode', type)
    end
  end

  def append_periodic_purchase_state(req, state)
    if state != nil
      append_param(req, 'periodicPurchaseStateCode', state)
    end
  end

  def append_periodic_purchase_schedule(req, schedule)
    if schedule != nil
      append_param(req, 'periodicPurchaseScheduleTypeCode', schedule.schedule_type)
      append_param(req, 'periodicPurchaseIntervalLength', schedule.interval_length)
    end
  end

  def append_periodic_purchase_transaction_id (req, periodic_transaction_id)
    append_param(req, 'periodicTransactionId', periodic_transaction_id)
  end

  def append_periodic_purchase_info (req, periodic_purchase_info)
    append_periodic_purchase_transaction_id(req, periodic_purchase_info.periodic_transaction_id)
    if periodic_purchase_info.per_payment_amount != nil
      append_amount(req, periodic_purchase_info.per_payment_amount)
    end

    if periodic_purchase_info.state !=nil
      append_periodic_purchase_state(req, periodic_purchase_info.state)
    end

    if periodic_purchase_info.schedule !=nil
      append_periodic_purchase_schedule(req, periodic_purchase_info.schedule)
    end

    if periodic_purchase_info.order_id !=nil
      append_order_id(req, periodic_purchase_info.order_id)
    end

    if periodic_purchase_info.customer_id !=nil
      append_param(req, 'customerId', periodic_purchase_info.customer_id)
    end

    if periodic_purchase_info.start_date !=nil
      append_start_date(req, periodic_purchase_info.start_date)
    end

    if periodic_purchase_info.end_date != nil
      append_end_date(req, periodic_purchase_info.end_date)
    end

    if periodic_purchase_info.next_payment_date !=nil
      append_param(req, 'nextPaymentDate', periodic_purchase_info.next_payment_date)
    end
  end

  def append_merchant_id(req, merchant_id)
    if merchant_id.kind_of? String
      append_param(req, 'merchantId', merchant_id.to_i)
    else
      append_param(req, 'merchantId', merchant_id)
    end
  end

  def append_order_id(req, order_id)
    append_param(req, 'orderId', order_id)
  end

  def append_param(req, name, value)
    if name.nil?
      return
    end

    unless value.nil?
      req[name] = value
    end
  end

  def append_transaction_id(req, transaction_id)
    append_param(req, 'transactionId', transaction_id)
  end

  def append_transaction_order_id(req, transaction_order_id)
    append_param(req, 'transactionOrderId', transaction_order_id)
  end

  def append_verification_request(req, vr)
    if vr != nil
      append_param(req, 'avsRequestCode', vr.get_avs_request)
      append_param(req, 'cvv2RequestCode', vr.get_cvv2_request)
    end
  end

  def append_storage_token_id(req, storage_token_id)
    append_param(req, 'storageTokenId', storage_token_id)
  end

  def append_total_number_installments(req, total_number_installments)
    append_param(req, 'totalNumberInstallments', total_number_installments)
  end

  def append_start_date(req, start_date)
    if start_date != nil
      append_param(req, 'startDate', start_date)
    end
  end

  def append_end_date(req, end_date)
    if end_date != nil
      append_param(req, 'endDate', end_date)
    end
  end

  def append_payment_profiles(req, payment_profile)
    unless payment_profile == nil
      if payment_profile.get_credit_card != nil
        append_credit_card(req, payment_profile.get_credit_card)
      end
      if payment_profile.get_customer_profile != nil
        append_param(req, 'profileLegalName', payment_profile.get_customer_profile.legal_name)
        append_param(req, 'profileTradeName', payment_profile.get_customer_profile.trade_name)
        append_param(req, 'profileWebsite', payment_profile.get_customer_profile.website)
        append_param(req, 'profileFirstName', payment_profile.get_customer_profile.first_name)
        append_param(req, 'profileLastName', payment_profile.get_customer_profile.last_name)
        append_param(req, 'profilePhoneNumber', payment_profile.get_customer_profile.phone_number)
        append_param(req, 'profileFaxNumber', payment_profile.get_customer_profile.fax_number)
        append_param(req, 'profileAddress1', payment_profile.get_customer_profile.address1)
        append_param(req, 'profileAddress2', payment_profile.get_customer_profile.address2)
        append_param(req, 'profileCity', payment_profile.get_customer_profile.city)
        append_param(req, 'profileProvince', payment_profile.get_customer_profile.province)
        append_param(req, 'profilePostal', payment_profile.get_customer_profile.postal)
        append_param(req, 'profileCountry', payment_profile.get_customer_profile.country)
      end
    end
  end

  def send(request, receipt_type)
    if request == nil && receipt_type == 'creditcard'
      raise InvalidRequest, 'a request string is required 25'
    end
    if request == nil && receipt_type == 'storage'
      raise InvalidRequest, 'a request string is required'
    end

    query_pairs = Array.new

    request.each { |key, value| query_pairs<< CGI::escape("#{key}")+'='+CGI::escape("#{value}") }
    query = query_pairs.join('&')

    receipt = nil
    response = nil

    url = URI.parse(@url)
    server = url.host
    path = url.path

    begin
      http = Net::HTTP.new(server, 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      headers = {'Content-Type' => 'application/x-www-form-urlencoded'}
      response, data = http.post(path, query, headers)
    rescue
      @error_msg = 'error attempting to send POST data'
      @error_code = $req_post_error
      return nil
    end
    begin
      case response
        when Net::HTTPSuccess
          if receipt_type =='creditcard'
            receipt = CreditCardReceipt.new(response.body)
          end
          if receipt_type == 'storage'
            receipt = StorageReceipt.new(response.body)
          end
        else
          @error_msg = "HTTP error code attempting to send POST request: #{response.code}"
          @error_code = $req_post_error
      end
    rescue
      @error_msg = 'Could not parse response from the CreditCard gateway'
      @error_code = $req_response_error
      return nil
    end
    receipt
  end
end

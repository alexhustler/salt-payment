require 'time'

$req_malformed_rul = -1
$req_post_error = -2
$req_response_error = -4
$req_connection_failed = -5
$req_invalid_request = -6

$market_segment_internet = 'I'
$market_segment_moto = 'M'
$market_segment_retail = 'G'

$avs_verify_street_and_zip = 0
$avs_verify_zip_only = 1

$cvv2_not_submitted = 0
$cvv2_present = 1
$cvv2_present_but_illegible = 2
$cvv2_has_no_cvv2 = 9

$month = 0
$week = 1
$day = 2

$new = 0
$in_progress = 1
$complete = 2
$on_hold = 3
$cancelled = 4

$date_format = 'yymmdd'

class ApprovalInfo
  attr_reader :get_authorized_amount, :get_approval_code, :get_trace_number, :get_reference_number

  def initialize(authorized_amount, approval_code, trace_number, reference_number)
    @get_authorized_amount = authorized_amount
    @get_approval_code = approval_code
    @get_trace_number = trace_number
    @get_reference_number = reference_number
  end
end

class AvsResponse
  attr_reader :avs_response_code, :avs_error_code, :avs_error_message, :zip_type, :street_matched
  attr_reader :zip_matched

  def initialize(avs_response_code, street_matched, zip_matched, zip_type, avs_error_code, avs_error_message)
    @avs_response_code = avs_response_code
    @street_matched = street_matched
    @zip_matched = zip_matched
    @zip_type = zip_type
    @avs_error_code = avs_error_code
    @avs_error_message = avs_error_message
  end

  def is_street_format_valid
    @street_matched !=nil
  end

  def is_street_format_valid_and_matched
    is_street_format_valid == true && @street_matched == true
  end

  def is_zip_format_valid
    @zip_matched != nil
  end

  def is_zip_format_valid_and_matched
    is_zip_format_valid == true && @zip_matched == true
  end

end

class AvsRequest
  attr_reader :code

  def initialize(code)
    @code = code
  end
end

class CreditCard
  attr_writer :credit_card_number, :expiry_date, :cvv2, :street
  attr_writer :zip, :secure_code

  attr_reader :get_credit_card_number, :get_expiry_date, :get_cvv2
  attr_reader :get_street, :get_secure_code, :get_zip

  def initialize(credit_card_number, expiry_date, cvv2=nil, street=nil, zip=nil, secure_code=nil, magnetic_data = nil)
    @credit_card_number = credit_card_number
    @expiry_date = expiry_date
    @cvv2 = cvv2
    @street = street
    @zip = zip
    @secure_code = secure_code

    @get_credit_card_number = @credit_card_number
    @get_expiry_date = @expiry_date
    @get_cvv2 = @cvv2
    @get_zip = @zip
    @get_street = @street
    @get_secure_code = @secure_code
  end
end

class CreditCardReceipt
  attr_accessor :error_code, :error_message, :debug_message, :processed_date_time

  attr_reader :is_approved, :get_error_code, :get_debug_message
  attr_reader :get_error_message, :get_approval_info, :get_avs_response
  attr_reader :get_cvv2_response, :get_order_id, :get_processed_date_time
  attr_reader :get_transaction_id, :get_periodic_purchase_info

  def initialize(response)
    @params = nil
    @approved = false
    @transaction_id = nil
    @order_id = nil
    @processed_date_time = nil #as a Time Object
    @processed_date_timestamp = nil #as a string (can apply your own format)
    @error_code = nil
    @error_message = nil
    @debug_message = nil
    @approval_info = nil
    @avs_response = nil
    @cvv2_response = nil
    @response = nil
    @periodic_purchase_info = nil

    if response == nil
      return
    end

    @response = response
    lines = @response.split("\n")
    @params = Hash::new

    lines.each do |value|
      param_key, param_value = value.split('=')
      @params[param_key] = param_value
    end

    #parse the param into data class objects
    @approved = @params['APPROVED'] == 'true'
    @transaction_id = @params['TRANSACTION_ID']
    @order_id = @params['ORDER_ID']
    processed_date = @params['PROCESSED_DATE']
    processed_time = @params['PROCESSED_TIME']

    if processed_date != nil && processed_time != nil
      year = processed_date.slice(0, 2)
      month = processed_date.slice(2, 2)
      day = processed_date.slice(4, 2)
      hour = processed_time.slice(0, 2)
      minute = processed_time.slice(2, 2)
      second = processed_time.slice(4, 2)

      @processed_date_timestamp = year+'-'+month+'-'+day+' '+hour+':'+minute+':'+second
      @processed_date_time = Time.parse(@processed_date_timestamp)

    else
      @processed_date_time = nil
    end

    @error_code = @params['ERROR_CODE']
    @error_message = @params['ERROR_MESSAGE']
    @debug_message = @params['DEBUG_MESSAGE']

    #parse Approval Info
    if @approved
      @approval_info = ApprovalInfo.new(
        @params['AUTHORIZED_AMOUNT'],
        @params['APPROVAL_CODE'],
        @params['TRACE_NUMBER'],
        @params['REFERENCE_NUMBER'])
    else
      @approval_info = nil
    end

    #parse AVS Response
    avs_response_available = @params['AVS_RESPONSE_AVAILABLE']
    if avs_response_available != nil && avs_response_available
      @avs_response = AvsResponse.new(
        @params['AVS_RESPONSE_CODE'],
        @params['STREET_MATCHED'],
        @params['ZIP_MATCHED'],
        @params['ZIP_TYPE'],
        @params['AVS_ERROR_CODE'],
        @params['AVS_ERROR_MESSAGE'])
    else
      @avs_response = nil
    end

    #parse Cvv2 Response
    cvv2_response_available = @params['CVV2_RESPONSE_AVAILABLE']
    if cvv2_response_available != nil && cvv2_response_available
      @cvv2_response = Cvv2Response.new(
        @params['CVV2_RESPONSE_CODE'],
        @params['CVV2_RESPONSE_MESSAGE'])
    else
      @cvv2_response = nil
    end

    #parse Periodic Purchase Info
    periodic_purchase_id = @params['PERIODIC_TRANSACTION_ID']
    if periodic_purchase_id != nil
      periodic_purchase_state = @params['PERIODIC_TRANSACTION_STATE']
      periodic_next_payment_date = @params['PERIODIC_NEXT_PAYMENT_DATE']
      periodic_last_payment_id = @params['PERIODIC_LAST_PAYMENT_ID']
      @periodic_purchase_info = PeriodicPurchaseInfo.new(periodic_purchase_id, periodic_purchase_state, nil, nil, nil, nil, nil, nil, periodic_next_payment_date, periodic_last_payment_id.to_s)
      #periodic_transaction_id, :state, :schedule, :per_payment_amount, :order_id, :customer_id, :start_date, :end_date, :next_payment_date
    else
      @periodic_purchase_info = nil
    end

    #set writer attributes:
    @is_approved = @approved
    @get_error_code = @error_code
    @get_debug_message = @debug_message
    @get_error_message = @error_message
    @get_approval_info = @approval_info
    @get_avs_response = @avs_response
    @get_cvv2_response = @cvv2_response
    @get_order_id = @order_id
    @get_processed_date_time = @processed_date_time
    @get_transaction_id = @transaction_id
    @get_periodic_purchase_info = @periodic_purchase_info
  end

  def error_only_receipt(error_code, error_message = nil, debug_message = nil)
    the_receipt = CreditCardReceipt.new('')
    the_receipt.error_code = error_code
    the_receipt.error_message = error_message
    the_receipt.debug_message = debug_message
    the_receipt.processed_date_time = Time.now
    the_receipt
  end
end

class Cvv2Response
  attr_reader :get_code, :get_message

  def initialize(code, message)
    @code = code
    @message = message

    @get_code = @code
    @get_message = @message
  end
end

class VerificationRequest
  attr_reader :get_avs_request, :get_cvv2_request

  def initialize(avs_request, cvv2_request)
    @avs_request = avs_request
    @cvv2_request = cvv2_request

    @get_avs_request = @avs_request
    @get_cvv2_request = @cvv2_request
  end
end

class CustomerProfile
  attr_accessor :legal_name, :trade_name, :website, :first_name
  attr_accessor :last_name, :phone_number, :fax_number, :address1
  attr_accessor :address2, :city, :province, :postal
  attr_accessor :country

  def initialize(legal_name = nil, trade_name = nil, website = nil, first_name = nil,
    last_name = nil, phone_number = nil, fax_number = nil, address1 = nil, address2 = nil,
    city = nil, province = nil, postal = nil, country = nil)
    @legal_name = legal_name
    @trade_name = trade_name
    @website = website
    @first_name = first_name
    @last_name = last_name
    @phone_number = phone_number
    @fax_number = fax_number
    @address1 = address1
    @address2 = address2
    @city = city
    @province = province
    @postal = postal
    @country = country
  end

  def is_blank
    con1 = @first_name !=nil && !@first_name.empty?
    con2 = @last_name != nil && !@last_name.empty?
    con3 = @legal_name !=nil && !@legal_name.empty?
    con4 = @trade_name != nil && !@trade_name.empty?
    con5 = @address1 != nil && !@address1.empty?
    con6 = @address2 != nil && !@address2.empty?
    con7 = @city != nil && !@city.empty?
    con8 = @province != nil && !@province.empty?
    con9 = @postal != nil && !@postal.empty?
    con10 = @country != nil && !@country.empty?
    con11 = @website != nil && !@website.empty?
    con12 = @phone_number != nil && !@phone_number.empty?
    con13 = @fax_number != nil && !@fax_number.empty?
    !(con1||con2||con3||con4||con5||con6||con7||con8||con9||con10||con11|con12||con13)
  end
end

class Merchant
  attr_accessor :merchant_id, :api_token, :store_id

  def initialize(*args)
    if args.size == 2
      # Merchant(merchant_id, api_token)
      @merchant_id = args[0]
      @api_token = args[1]
    else
      # Merchant(merchant_id, api_token, store_id)
      @merchant_id = args[0]
      @api_token = args[1]
      @store_id = args[2]
    end
  end
end

class StorageReceipt
  attr_accessor :errorCode, :errorMessage, :debugMessage, :processedDateTime

  attr_reader :get_payment_profile, :get_storage_token_id, :get_debug_message
  attr_reader :get_error_code, :get_error_message, :get_order_id
  attr_reader :get_processed_date_time, :get_transaction_id, :is_approved

  def initialize(response)
    @params = nil
    @approved = false
    @transaction_id = nil
    @order_id = nil
    @processed_date_time = nil
    @error_code = nil
    @error_message = nil
    @debug_message = nil
    @response = nil
    @payment_profile = nil
    @storage_token_id = nil

    if response == nil
      return
    end

    @response = response
    lines = @response.split("\n")
    @params = Hash::new

    lines.each do |value|
      param_key, param_value = value.split('=')
      @params[param_key] = param_value
    end

    @approved = @params['APPROVED'] == 'true'
    @storage_token_id = @params['STORAGE_TOKEN_ID']
    @error_code = @params['ERROR_CODE']
    @error_message = @params['ERROR_MESSAGE']
    @debug_message = @params['DEBUG_MESSAGE']

    payment_profile_available = @params['PAYMENT_PROFILE_AVAILABLE']

    processed_date = @params['PROCESSED_DATE']
    processed_time = @params['PROCESSED_TIME']

    if processed_date != nil && processed_time != nil
      year = processed_date.slice(0, 2)
      month = processed_date.slice(2, 2)
      day = processed_date.slice(4, 2)
      hour = processed_time.slice(0, 2)
      minute = processed_time.slice(2, 2)
      second = processed_time.slice(4, 2)
      time = year+'-'+month+'-'+day+' '+hour+':'+minute+':'+second
      @processed_date_time = Time.parse(time)
    else
      @processed_date_time = nil
    end

    if payment_profile_available != nil && payment_profile_available
      credit_card = nil
      credit_card_available = @params['CREDIT_CARD_AVAILABLE']

      if credit_card_available != nil && credit_card_available
        sanitized = @params['CREDIT_CARD_NUMBER']
        sanitized = sanitized.gsub("\\*", '')
        credit_card = CreditCard.new(sanitized, @params['EXPIRY_DATE'])
      end

      profile = nil
      customer_profile_available = @params['CUSTOMER_PROFILE_AVAILABLE']

      if customer_profile_available != nil && customer_profile_available
        profile = CustomerProfile.new(
          @params['CUSTOMER_PROFILE_LEGAL_NAME'],
          @params['CUSTOMER_PROFILE_TRADE_NAME'],
          @params['CUSTOMER_PROFILE_WEBSITE'],
          @params['CUSTOMER_PROFILE_FIRST_NAME'],
          @params['CUSTOMER_PROFILE_LAST_NAME'],
          @params['CUSTOMER_PROFILE_PHONE_NUMBER'],
          @params['CUSTOMER_PROFILE_FAX_NUMBER'],
          @params['CUSTOMER_PROFILE_ADDRESS1'],
          @params['CUSTOMER_PROFILE_ADDRESS2'],
          @params['CUSTOMER_PROFILE_CITY'],
          @params['CUSTOMER_PROFILE_PROVINCE'],
          @params['CUSTOMER_PROFILE_COUNTRY']
        )
      end

      @payment_profile = PaymentProfile.new(credit_card, profile)
    else
      @payment_profile = nil
    end
    #read methods:
    @get_payment_profile = @payment_profile
    @get_storage_token_id = @storage_token_id
    @get_debug_message = @debug_message
    @get_error_code = @error_code
    @get_error_message = @error_message
    @get_order_id = @order_id
    @get_processed_date_time = @processed_date_time
    @get_transaction_id = @transaction_id
    @is_approved = @approved
  end

  def error_only_receipt(error_code, error_message = nil, debug_message = nil)
    the_receipt = Hash::new
    the_receipt['errorCode'] = error_code
    the_receipt['errorMsg'] = error_message
    the_receipt['debugMsg'] = debug_message
    the_receipt['processedDateTime'] = Time.now
    the_receipt
  end
end

class Schedule
  attr_accessor :schedule_type, :interval_length

  def initialize(type, interval_length)
    @schedule_type = type
    @interval_length = interval_length
  end

end

class PaymentProfile
  attr_reader :get_credit_card, :get_customer_profile

  def initialize(credit_card, customer_profile)
    @credit_card = credit_card
    @customer_profile = customer_profile

    @get_credit_card = @credit_card
    @get_customer_profile = @customer_profile
  end

  def set_credit_card(new_credit_card)
    @credit_card = new_credit_card
  end

  def set_customer_profile(new_customer_profile)
    @customer_profile = new_customer_profile
  end
end

class PeriodicPurchaseInfo
  attr_reader :periodic_transaction_id, :state, :schedule, :per_payment_amount, :order_id, :customer_id, :start_date, :end_date, :next_payment_date, :last_payment_id

  def initialize(periodic_transaction_id, state, schedule, per_payment_amount =nil, order_id =nil, customer_id =nil, start_date =nil, end_date =nil, next_payment_date = nil, last_payment_id = nil)
    @periodic_transaction_id = periodic_transaction_id
    @state = state
    @schedule = schedule
    @start_date = start_date
    @end_date = end_date
    @per_payment_amount = per_payment_amount
    @order_id = order_id
    @customer_id = customer_id
    @next_payment_date = next_payment_date
    @last_payment_id = last_payment_id
  end
end

class InvalidRequest < StandardError
end
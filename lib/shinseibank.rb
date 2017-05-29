# Your code goes here...
# -*- encoding: utf-8 -*-
#
#  新生銀行
#  Shinsei power direct client
#
# @author binzume  http://www.binzume.net/

require "shinseibank/version"
require 'kconv'
require 'time'
require 'shinseibank/httpclient'
require 'yaml'

class ShinseiBank

  attr_reader :account_status, :accounts, :funds, :last_html
  attr_accessor :account

  def initialize(account = nil)
    @account_status = {:total=>nil}
    @base_url = 'https://pdirect04.shinseibank.com/FLEXCUBEAt'
    @url = "#{@base_url}/LiveConnect.dll"
    ua = "Mozilla/5.0 (Windows; U; Windows NT 5.1;) PowerDirectBot/0.1"
    @client = HTTPClient.new(:agent_name => ua)

    @toutf8 = lambda { |v| v.toutf8 }
    @parse_i = lambda { |v| v.gsub(/[,\.]/,'').to_i }
    @parse_f = lambda { |v| v.gsub(/,/,'').to_f }

    if account
      login(account)
    end
  end

  ##
  # ログイン
  #
  # @param [Hash] account アカウント情報(see shinsei_account.yaml.sample)
  def login(account = 'shinsei_account.yaml')

    if account.is_a?(String)
      @account = YAML.load_file(account)
    elsif account.is_a?(Hash)
      @account = account
    end

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'LGN',
      'fldScrSeqNo'=>'01',
      'fldRequestorID'=>'41',
      'fldDeviceID'=>'01',
      'fldLangID'=>'JPN',
      'fldUserID'=> @account['ID'],
      'fldUserNumId'=> @account['NUM'],
      'fldUserPass'=> @account['PASS'],
      'fldRegAuthFlag'=>'A'
    }

    res = @client.post(@url, postdata)

    values= {}
    ['fldSessionID', 'fldGridChallange1', 'fldGridChallange2', 'fldGridChallange3', 'fldRegAuthFlag'].each{|k|
      if res.body =~/#{k}=['"](\w+)['"]/
        values[k] = $1
      end
    }

    @ssid = values['fldSessionID']

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'LGN',
      'fldScrSeqNo'=>'41',
      'fldRequestorID'=>'55',
      'fldSessionID'=> @ssid,
      'fldDeviceID'=>'01',
      'fldLangID'=>'JPN',
      'fldGridChallange1'=>getgrid(@account, values['fldGridChallange1']),
      'fldGridChallange2'=>getgrid(@account, values['fldGridChallange2']),
      'fldGridChallange3'=>getgrid(@account, values['fldGridChallange3']),
      'fldUserID'=>'',
      'fldUserNumId'=>'',
      'fldNumSeq'=>'1',
      'fldRegAuthFlag'=>values['fldRegAuthFlag'],
    }

    @client.post(@url, postdata)

    get_accounts
  end

  ##
  # ログアウト
  def logout
    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'CDC',
      'fldScrSeqNo'=>'49',
      'fldRequestorID'=>'',
      'fldSessionID'=> @ssid,

      'fldIncludeBal'=>'Y',
      'fldCurDef'=>'JPY'
    }

    #p postdata
    @client.post(@url, postdata)
  end

  ##
  # 残高確認
  #
  # @return [int] 残高(yen)
  def total_balance
    @account_status[:total]
  end

  ##
  # 直近の取引履歴(円口座)
  #
  # @return [Array] 履歴の配列
  def recent
    get_history nil, nil, @accounts.keys[0]
  end

  def get_accounts

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'ACS',
      'fldScrSeqNo'=>'00',
      'fldRequestorID'=>'23',
      'fldSessionID'=> @ssid,

      'fldAcctID'=>'', # 400????
      'fldAcctType'=>'CHECKING',
      'fldIncludeBal'=>'Y',
      'fldPeriod'=>'',
      'fldCurDef'=>'JPY'
    }

    #p postdata
    res = @client.post(@url, postdata)
    #puts res.body

    accounts = parse_array(res.body, [
      ['fldAccountID', :id],
      ['fldAccountType', :type],
      ['fldAccountDesc', :description, @toutf8],
      ['fldCurrCcy', :currency],
      ['fldCurrBalance', :balance, @parse_f],
      ['fldBaseBalance', :base_balance, @parse_f],
    ])

    @accounts = accounts.map { |e| [e[:id], e] }.to_h

    @funds = parse_array(res.body, [
      ['fldFundNameLCYArray', :name, @toutf8],
      ['fldUnitsLCYArray', :holding, @parse_i],
      ['fldUnitsLCYArray', :base_curr, @parse_f],
      ['fldYenEqvLCYArray', :current_nav, @parse_f],
    ])

    total = 0
    if res.body =~/fldGrandTotalCR="([\d\.,]+)"/
      total = $1.gsub(/,/,'').to_i
    end

    @account_status = {:total=>total}
  end

  def get_history from,to,id

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'ACA',
      'fldScrSeqNo'=>'01',
      'fldRequestorID'=>'9',
      'fldSessionID'=> @ssid,

      'fldAcctID'=> id, # 400????
      'fldAcctType'=>@accounts[id][:type],
      'fldIncludeBal'=>'N',

      'fldStartDate'=> from ? from.strftime('%Y%m%d') : '',
      'fldEndDate'=> to ? to.strftime('%Y%m%d') : '',
      'fldStartNum'=>'0',
      'fldEndNum'=>'0',
      'fldCurDef'=>'JPY',
      'fldPeriod'=> (from && too) ? "2" : "1"
    }

    #p postdata
    res = @client.post(@url, postdata)

    history = parse_array(res.body, [
      ['fldDate', :date],
      ['fldDesc', :description, @toutf8 ],
      ['fldRefNo', :ref_no],
      ['fldDRCRFlag', :type, lambda { |v| v == 'D' ? :debit : :credit } ],
      ['fldAmount', :amount, @parse_i ],
      ['fldRunningBalanceRaw', :balance, @parse_i ],
    ])

    @account_status = {:total=>history[0][:amount], :id=>id}
    history[1..-1]
  end

  ##
  # transfer to registered account
  #
  # @param [string] name = target 7digit account num. TODO:口座番号被る可能性について考える
  # @param [int] amount < 2000000 ?
  def transfer_to_registered_account name, amount, remitter_info: nil, remitter_info_pos: nil

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'ZNT',
      'fldScrSeqNo'=>'00',
      'fldRequestorID'=>'71',
      'fldSessionID'=> @ssid,
    }

    #p postdata
    res = @client.post(@url, postdata)

    registered_accounts = parse_array(res.body, [
      ['fldListPayeeAcctId', :account_id],
      ['fldListPayeeAcctType', :account_type],
      ['fldListPayeeName', :name],
      ['fldListPayeeBank', :bank],
      ['fldListPayeeBankKanji', :bank_kanji],
      ['fldListPayeeBankKana', :bank_kana],
      ['fldListPayeeBranch', :branch],
      ['fldListPayeeBranchKanji', :branch_kanji],
      ['fldListPayeeBranchKana', :branch_kana],
    ])

    values= {}
    ['fldRemitterName', 'fldInvoice', 'fldInvoicePosition','fldDomFTLimit', 'fldRemReimburse'].each{|k|
      if res.body =~/#{k}=['"]([^'"]*)['"]/
        values[k] = $1
      end
    }

    target_account = registered_accounts.find{|a| a[:account_id] == name  };
    from_name = values['fldRemitterName']
    account = @accounts.keys[0] # とりあえず普通円預金っぽいやつ

    if remitter_info
      values['fldMemo'] = remitter_info_pos.to_sym == :after ? "#{from_name}#{remitter_info}" : "#{remitter_info}#{from_name}"
      values['fldInvoicePosition'] = remitter_info_pos.to_sym == :after ? 'A' : 'B'
      values['fldInvoice'] = remitter_info
    else
      values['fldMemo'] = from_name
    end

    values.merge!({
      'fldAcctId' => account,
      'fldAcctType' => @accounts[account][:type] ,
      'fldAcctDesc'=> @accounts[account][:desc],
      'fldTransferAmount' => amount,
      'fldTransferType'=>'P', # P(registerd) or D
      #'fldPayeeId'=>'',
      'fldPayeeName' => target_account[:name],
      'fldPayeeAcctId' => target_account[:account_id],
      'fldPayeeAcctType' => target_account[:account_type],
      #fldPayeeBankCode:undefined
      'fldPayeeBankName' => target_account[:bank],
      'fldPayeeBankNameKana' => target_account[:bank_kana],
      'fldPayeeBankNameKanji' => target_account[:bank_kanji],
      #fldPayeeBranchCode:undefined
      'fldPayeeBranchName' => target_account[:branch],
      'fldPayeeBranchNameKana' => target_account[:branch_kana],
      'fldPayeeBranchNameKanji' => target_account[:branch_kanji],
      #fldSearchBankName:
      #fldSearchBranchName:
      #fldFlagRegister:
      #'fldDomFTLimit'=>'4000000',
    })

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'ZNT',
      'fldScrSeqNo'=>'07',
      'fldRequestorID'=>'74',
      'fldSessionID'=> @ssid,
    }.merge(values)

    res = @client.post(@url, postdata)

    ['fldMemo', 'fldInvoicePosition', 'fldTransferType', 'fldTransferDate', 'fldTransferFeeUnformatted',
     'fldDebitAmountUnformatted', 'fldReimbursedAmt', 'fldRemReimburse'].each{|k|
      if res.body =~/#{k}=['"]([^'"]*)['"]/
        values[k] = $1
      end
    }

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'ZNT',
      'fldScrSeqNo'=>'08',
      'fldRequestorID'=>'76',
      'fldSessionID'=> @ssid,
    }.merge(values)

    #p postdata
    res = @client.post(@url, postdata)

    @last_html = res.body
  end


  ##
  # 投資信託買う(実装中…)
  #
  # @param [Hash] fund 投資信託情報
  # @param [int] amount yen
  def buy_fund fund, amount
    acc = @accounts.values.find{|a| a[:curr] == fund[:curr]}

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'IS',
      'fldTxnID'=>'BMF',
      'fldScrSeqNo'=>'02',
      'fldRequestorID'=>'4',
      'fldSessionID'=> @ssid,

      'fldPayMode'=> 'BANKXFER',
      'fldMFID'=> fund[:id],
      'fldBuyType'=> 'AMOUNT',
      'fldBuyUnits'=> amount,
      'fldTxnCurr'=> acc[:curr],
      'fldAcctID'=> acc[:id],
      'fldAcctType'=> 'SAVINGS', # acc[:type]?
      'fldAcctCurr'=> acc[:curr],
      'fldBankID'=> '397', # shinsei-bank
      'fldBranchID'=> acc[:id][0..2],
      'fldUHID'=> fund[:uhid],
      'fldAcctBalance'=> acc[:balance].to_i,
      'fldLOIApplicable'=> '0',
      'fldCertReqd'=> '0',
      'fldSingleCert'=> '0',
      'fldGrossOrNet'=> 'GROSS',
      'fldUserOverride'=> '',
      'fldTkEnabled'=> '0',
      'fldMfTk'=> '1',
      'fldTkApplicable'=>'0',
    }

    res = @client.post(@url, postdata)

    values = {}
    ['fldFundID', 'fldBuyType', 'fldBuyUnits', 'fldTxnCurr', 'fldPayMode', 'fldAcctID', 'fldAcctType', 'fldBankID',
     'fldAcctCurr', 'fldBranchID', 'fldPayCCIssuersType', 'fldPayCCNo', 'fldPayCCExpiryDate','fldUHID', 'fldLOIApplicable',
     'fldCertReqd','fldGrossOrNet','fldSingleCert','fldAcctBalance', 'fldUserOverride','fldTkEnabled', 'fldMfTk',
     'fldTkApplicable','fldUHCategory','fldFCISDPRefNo','fldTransactionDate','fldAllocationDate', 'fldConfirmationDate', 'fldPreCalcFlag',
     'fldFeeAmount', 'fldTaxAmount', 'fldUnits'].each{|k|
       if res.body =~/#{k}=['"]([^'"]*)['"]/
         values[k] = $1
       end
     }

     values['fldUserOverride'] = 'Y'

     postdata = {
       'MfcISAPICommand'=>'EntryFunc',
       'fldAppID'=>'IS',
       'fldTxnID'=>'BMF',
       'fldScrSeqNo'=>'03',
       'fldRequestorID'=>'6',
       'fldSessionID'=> @ssid,

       'fldDefFundID' => values['fldFundID'],
       'fldDefBuyType' => values['fldBuyType'],
       'fldDefBuyUnits' => values['fldBuyUnits'],
       'fldDefTxnCurr' => values['fldTxnCurr'],
       'fldDefPayMode' => values['fldPayMode'],
       'fldDefPayAcctID' => values['fldAcctID'],
       'fldDefPayAcctType' => values['fldAcctType'],
       'fldDefPayBankID' => values['fldBankID'],
       'fldDefAcctCurr' => values['fldAcctCurr'],
       'fldDefPayBranchID' => values['fldBranchID'],
       'fldDefPayCCIssuersType' => values['fldPayCCIssuersType'],
       'fldDefPayCCNo' => values['fldPayCCNo'],
       'fldDefPayCCExpiryDate' => values['fldPayCCExpiryDate'],
       'fldUHID' => values['fldUHID'],
       'fldLOIApplicable' => values['fldLOIApplicable'],
       'fldCertReqd' => values['fldCertReqd'],
       'fldGrossOrNet' => values['fldGrossOrNet'],
       'fldSingleCert' => values['fldSingleCert'],
       'fldAcctBalance' => values['fldAcctBalance'],
       'fldUserOverride' => values['fldUserOverride'],
       'fldTkEnabled' => values['fldTkEnabled'],
       'fldMfTk' => values['fldMfTk'],
       'fldTkApplicable' => values['fldTkApplicable'],
       'fldUHCategory' => values['fldUHCategory'],
       'fldFCISDPRefNo' => values['fldFCISDPRefNo'],
       'fldTransactionDate' => values['fldTransactionDate'].gsub('/',''),
       'fldAllocationDate' => values['fldAllocationDate'].gsub('/',''),
       'fldConfirmationDate' => values['fldConfirmationDate'].gsub('/',''),
       'fldPreCalcFlag' => values['fldPreCalcFlag'],
     }

     # デバッグ用．確定しない
     #p postdata
     #res = @client.post(@url, postdata)
     @last_html = res.body

     unless values['fldUnits']
       return nil
     end

     {:method => 'buy_fund', :units => values['fldUnits'].gsub(',','').to_i , :alloc_date => values['fldAllocationDate'] ,:postdata => postdata }
  end

  ##
  # 投資信託売る
  #
  # @param [Hash] fund 投資信託情報( funds()で得たもののいずれか )
  # @param [Int] amount:口数
  def sell_fund fund, amount

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'IS',
      'fldTxnID'=>'SMF',
      'fldScrSeqNo'=>'01',
      'fldRequestorID'=>'15',
      'fldSessionID'=> @ssid,

      'fldDefFundID'=>fund[:id],
      'fldCDCCode'=>'',
      'fldUHID'=>fund[:uhid],
      'fldTkApplicable'=>'0',
    }
    res = @client.post(@url, postdata)

    acc= {}
    ['fldBankIDArray', 'fldBranchIDArray', 'fldAcctIDArray', 'fldAcctTypeArray', 'fldAcctCurrArray',
     'fldDebitAmountUnformatted', 'fldReimbursedAmt', 'fldRemReimburse'].each{|k|
      if res.body =~/#{k}\[0\]\[0\]=['"]([^'"]*)['"]/
        acc[k] = $1
      end
    }

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'IS',
      'fldTxnID'=>'SMF',
      'fldScrSeqNo'=>'02',
      'fldRequestorID'=>'16',
      'fldSessionID'=> @ssid,

      'fldMFID'=>fund[:id],
      'fldRdmMode'=>'BANKXFER',
      'fldAcctID'=> acc['fldAcctIDArray'],
      'fldAcctType'=>acc['fldAcctTypeArray'],
      'fldAcctCurr'=>acc['fldAcctCurrArray'],
      'fldBankID'=>acc['fldBankIDArray'],
      'fldBranchID'=>acc['fldBranchIDArray'],
      'fldUHID'=>fund[:uhid],
      'fldTxnCurr'=> acc['fldAcctCurrArray'],
      'fldSellType'=>'UNITS',
      'fldSellUnits'=>amount,
      'fldGrossOrNet'=>'GROSS',
      'fldTkApplicable'=> '0',
    }

    #p postdata
    res = @client.post(@url, postdata)

    values= {}
    ['fldEODRunning', 'fldTkApplicable', 'fldAllocationDate', 'fldPaymentDate', 'fldConfirmationDate',
     'fldTransactionDate', 'fldFCISDPRefNo', 'fldSettlementAmt'].each{|k|
      if res.body =~/#{k}=['"]([^'"]*)['"]/
        values[k] = $1
      end
    }

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'IS',
      'fldTxnID'=>'SMF',
      'fldScrSeqNo'=>'03',
      'fldRequestorID'=>'17',
      'fldSessionID'=> @ssid,

      'fldDefFundID'=>fund[:id],
      'fldDefSellType'=>'UNITS',
      'fldDefSellUnits'=>amount,
      'fldDefTxnCurr'=> acc['fldAcctCurrArray'],
      'fldDefRdmMode'=>'BANKXFER',
      'fldDefAcctID'=> acc['fldAcctIDArray'],
      'fldDefAcctType'=>acc['fldAcctTypeArray'],
      'fldDefBankID'=>acc['fldBankIDArray'],
      'fldDefBranchID'=>acc['fldBranchIDArray'],
      'fldDefAcctCurr'=>acc['fldAcctCurrArray'],
      'fldUHID'=>fund[:uhid],
      'fldGrossOrNet'=>'GROSS',

      'fldEODRunning'=> values['fldEODRunning'],
      'fldUserOverride'=>'Y',
      'fldFCISDPRefNo'=> values['fldFCISDPRefNo'],
      'fldTransactionDate'=> values['fldTransactionDate'].gsub('/',''),
      'fldAllocationDate'=> values['fldAllocationDate'].gsub('/',''),
      'fldConfirmationDate'=> values['fldConfirmationDate'].gsub('/',''),
      'fldPaymentDate'=> values['fldPaymentDate'].gsub('/',''),
      'fldPreCalcFlag'=>'Y',
      'fldTkApplicable'=> values['fldTkApplicable'],
    }

    # デバッグ用．確定しない
    #p postdata
    #res = @client.post(@url, postdata)
    @last_html = res.body

    {:method => 'sell_fund' , :amount=>values['fldSettlementAmt'].gsub(',','').to_f,  :alloc_date => values['fldAllocationDate'], :postdata => postdata }
  end

  ##
  # 確定する
  #
  # @param [Hash] data sell_fundやbuy_fundの結果
  def confirm data
    res = @client.post(@url, data[:postdata])
    @last_html = res.body
  end

  def fund_history fund, from = nil, to = nil

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'IS',
      'fldTxnID'=>'TXN',
      'fldScrSeqNo'=>'02',
      'fldRequestorID'=>'30',
      'fldSessionID'=> @ssid,

      'fldINCTRAN'=>'N',
      'fldINCOO'=>'N',
      'fldINCPOS'=>'N',
      'fldINCBAL'=>'N',
      'fldFundID'=> fund[:id],
      'fldUHID'=> fund[:uhid],
      'fldCriteria'=>'NOOFTRAN',
      'fldStartDate'=> from ? from.strftime('%Y%m%d') : '',
      'fldEndDate'=> to ? to.strftime('%Y%m%d') : '',
      'fldNoOfTran'=>'',
      'fldNoOfTranPerScreen'=>'10',
      'fldStartNum'=>'0',
      'fldEndNum'=>'0',
      'fldCurDef'=>'JPY',
      'fldPrevNext'=>'H',
      'fldIncludeBal'=>'Y',
      'fldPolicyNumber'=>'UT'
    }

    #p postdata
    res = @client.post(@url, postdata)

    parse_array(res.body, [
      ['fldTxnDateArray', :date],
      ['fldDateAlloted', :alloc_date],
      ['fldRefNoArray', :ref_no],
      ['fldTxnTypeArray', :type],
      ['fldAmountArray', :units, @parse_i ],
      ['fldStlmntAmtFormatted', :amount, @parse_i ],
    ])

  end

  def all_funds

    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'IS',
      'fldTxnID'=>'BMF',
      'fldScrSeqNo'=>'00',
      'fldRequestorID'=>'1',
      'fldSessionID'=> @ssid,

      'fldflgUHID'=>'N',
      'fldALPHALIST'=>'Y',
      'fldInvObjective'=>'2',
      'fldInvNature'=>'2',
      'fldInvExp'=>'2',
      'fldFinSituation'=>'2',
    }

    #p postdata
    res = @client.post(@url, postdata)

    uhids = []
    res.body.scan(/fldTopUHIDArray\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                          uhids[m[1].to_i] = m[2]
    }


    funds = []

    res.body.scan(/fldFundIDArray\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                         funds[m[1].to_i] = {:id=>m[2], :uhid=>uhids[0]}
    }

    res.body.scan(/fldFundNameArray\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                           funds[m[1].to_i][:name] = m[2].toutf8
    }

    res.body.scan(/fldFundRiskLevel\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                           funds[m[1].to_i][:risk_level] = m[2].to_i
    }

    res.body.scan(/fldFundCategoryName\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                              funds[m[1].to_i][:category_name] = m[2].toutf8
    }

    res.body.scan(/fldFundCategory\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                          funds[m[1].to_i][:category] = m[2]
    }


    res.body.scan(/fldFundURLArray\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                          funds[m[1].to_i][:url] = m[2].toutf8
    }

    funds
  end

  def get_csv_statement(id: nil, from: nil, to: nil)
    id ||= @accounts.keys.first

    to ||= Date.today if from

    if to && !from
      raise ArgumentError.new("You need to provide a range start if you provide a range end.")
    elsif from && from > to
      raise ArgumentError.new("Invalid range.")
    end

    from = from.strftime("%Y%m%d") if from
    to = to.strftime("%Y%m%d") if to

    postdata = {
      "MfcISAPICommand" => "EntryFunc",
      "fldScrSeqNo" => "01",
      "fldAppID" => "RT",
      'fldSessionID'=> @ssid,
      "fldTxnID" => "ACA",
      "fldRequestorID" => "9",
      "fldAcctID" => id.to_s,
      "fldAcctType" => @accounts[id][:type],
      "fldIncludeBal" => "N",
      "fldStartDate" => from,
      "fldEndDate" => to,
      "fldStartNum" => "0",
      "fldEndNum" => "0",
      "fldCurDef" => "JPY",
      "fldPeriod" => (from ? "2" : "1"),
    }
    res = @client.post(@url, postdata)

    postdata["fldTxnID"] = "DAA"

    res = @client.post(@url, postdata)
    body = res.body.toutf8
    csv = body.lines[9..-1].join
    require "csv"
    headers = [:date, :ref_no, :description, :debit, :credit, :balance]
    CSV.parse(csv, col_sep: "\t", headers: headers)
  end

  def get_transfer_history
    postdata = {
      "MfcISAPICommand" => "EntryFunc",
      "fldAppID" => "RT",
      "fldTxnID" => "ZNI",
      "fldScrSeqNo" => "00",
      "fldRequestorID" => "90",
      "fldSessionID" => @ssid,
      "fldAcctID" => "",
      "fldAccountType" => "",
      "fldIncludeBal" => "Y",
      "fldCurDef" => "JPY",
      "fldCDCCode" => "",
      "fldStartNum" => "0",
      "fldEndNum" => "10",
      "fldLink" => "",
      "fldbRktnVisited" => "",
      "fldCustCat" => "",
      "fldCustAcctStatus" => "",
    }
    res = @client.post(@url, postdata)
    body = res.body.toutf8

    parse_array(body, [
      ['fldListDebitAcctID', :origin],
      ['fldListTxnAmount', :amount],
      ['fldListTxnFee', :fee],
      ['fldListPayeeAcctID', :payee_account_id],
      ['fldListPayeeBnkBrn', :payee_bank_branch],
      ['fldListDatValue', :date],
      ['fldListPayeeName', :payee_name],
      ['fldListRefSysTrAudNo', :reference],
      ['fldListTxtRemarks1', :remarks],
      ['fldListTxnStatus', :status],
    ])
  end

  private
  def getgrid account, cell
    x = cell[0].tr('A-J', '0-9').to_i
    y = cell[1].to_i

    account['GRID'][y][x]
  end

  def parse_array(body, keys)
    res = []
    keys.each do |k,v,bl|
      bl ||= Proc.new { |m| m }
      body.scan(/#{k}\[(\d+)\]="([^"]+)"/) do
        m = Regexp.last_match
        res[m[1].to_i] ||= {}
        res[m[1].to_i][v] = bl.call(m[2])
      end
    end
    res
  end

end

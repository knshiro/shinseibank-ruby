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
require 'shinseibank/request'

class ShinseiBank
  attr_reader :credentials, :account_status, :accounts, :funds, :last_html

  URL = "https://pdirect04.shinseibank.com/FLEXCUBEAt/LiveConnect.dll".freeze
  USER_AGENT = "Mozilla/5.0 (Windows; U; Windows NT 5.1;) PowerDirectBot/0.1".freeze

  ##
  # Connect
  #
  # @param [Hash] credentials アカウント情報(see shinsei_account.yaml.sample)
  def self.connect(credentials)
    new(credentials).tap(&:login).tap(&:get_accounts)
  end

  def initialize(credentials)
    @credentials = credentials
  end

  def login
    request = Request.new(
      :post,
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'LGN',
      'fldScrSeqNo'=>'01',
      'fldRequestorID'=>'41',
      'fldDeviceID'=>'01',
      'fldLangID'=>'JPN',
      'fldUserID'=> credentials["account"],
      'fldUserNumId'=> credentials["pin"],
      'fldUserPass'=> credentials["password"],
      'fldRegAuthFlag'=>'A'
    )

    data = request.perform

    @ssid = data['fldSessionID']

    Request.new(
      :post,
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'LGN',
      'fldScrSeqNo'=>'41',
      'fldRequestorID'=>'55',
      'fldSessionID'=> @ssid,
      'fldDeviceID'=>'01',
      'fldLangID'=>'JPN',
      'fldGridChallange1'=>getgrid(data['fldGridChallange1']),
      'fldGridChallange2'=>getgrid(data['fldGridChallange2']),
      'fldGridChallange3'=>getgrid(data['fldGridChallange3']),
      'fldUserID'=>'',
      'fldUserNumId'=>'',
      'fldNumSeq'=>'1',
      'fldRegAuthFlag'=>data['fldRegAuthFlag'],
    ).perform
  end

  ##
  # ログアウト
  def logout
    Request.new(
      :post,
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'CDC',
      'fldScrSeqNo'=>'49',
      'fldRequestorID'=>'',
      'fldSessionID'=> @ssid,

      'fldIncludeBal'=>'Y',
      'fldCurDef'=>'JPY'
    ).perform

    @ssid = nil
  end

  ##
  # 残高確認
  #
  # @return [int] 残高(yen)
  def total_balance
    @account_status[:total]
  end

  def get_history(from: nil, to: nil, id: nil)
    get_csv_statement(from: from, to: to, id: id).map(&:to_h)
  end

  def get_accounts
    data = Request.new(
      :post,
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
    ).perform

    @accounts = data["fldAccountID"].map.with_index do |id, index|
      [
        id,
        {
          id: id,
          type: data["fldAccountType"][index],
          description: data["fldAccountDesc"][index],
          currency: data["fldCurrCcy"][index],
          balance: data["fldCurrBalance"][index],
          base_balance: data["fldBaseBalance"][index]
        }
      ]
    end.to_h

    @funds = data["fldFundNameLCYArray"].map.with_index do |name, index|
      {
        name: name,
        holding: data["fldUnitsLCYArray"][index],
        base_curr: data["fldNAVLCYArray"][index],
        current_nav: data["fldYenEqvLCYArray"][index]
      }
    end

    @account_status = {
      total: data.fetch("fldGrandTotalCR", 0)
    }
  end

  def list_registered_accounts
    postdata = {
      'MfcISAPICommand'=>'EntryFunc',
      'fldAppID'=>'RT',
      'fldTxnID'=>'ZNT',
      'fldScrSeqNo'=>'00',
      'fldRequestorID'=>'71',
      'fldSessionID'=> @ssid,
    }

    #p postdata
    body = post(postdata)

    registered_accounts = parse_array(body, [
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

    registered_accounts
  end

  def show_registered_accounts
    list_registered_accounts.map { |e| e.each { |k,v| e[k] = v } }
  end

  ##
  # transfer to registered account
  #
  # @param [string] name = target 7digit account num. TODO:口座番号被る可能性について考える
  # @param [int] amount < 2000000 ?
  def transfer_to_registered_account name, amount, remitter_info: nil, remitter_info_pos: nil

    registered_accounts = list_registered_accounts
    res = @last_res

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

    body = post(postdata)

    ['fldMemo', 'fldInvoicePosition', 'fldTransferType', 'fldTransferDate', 'fldTransferFeeUnformatted',
     'fldDebitAmountUnformatted', 'fldReimbursedAmt', 'fldRemReimburse'].each{|k|
      if body =~/#{k}=['"]([^'"]*)['"]/
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
    post(postdata)
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

    body = post(postdata)

    values = {}
    ['fldFundID', 'fldBuyType', 'fldBuyUnits', 'fldTxnCurr', 'fldPayMode', 'fldAcctID', 'fldAcctType', 'fldBankID',
     'fldAcctCurr', 'fldBranchID', 'fldPayCCIssuersType', 'fldPayCCNo', 'fldPayCCExpiryDate','fldUHID', 'fldLOIApplicable',
     'fldCertReqd','fldGrossOrNet','fldSingleCert','fldAcctBalance', 'fldUserOverride','fldTkEnabled', 'fldMfTk',
     'fldTkApplicable','fldUHCategory','fldFCISDPRefNo','fldTransactionDate','fldAllocationDate', 'fldConfirmationDate', 'fldPreCalcFlag',
     'fldFeeAmount', 'fldTaxAmount', 'fldUnits'].each{|k|
       if body =~/#{k}=['"]([^'"]*)['"]/
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
     #res = post(postdata)

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
    body = post(postdata)

    acc= {}
    ['fldBankIDArray', 'fldBranchIDArray', 'fldAcctIDArray', 'fldAcctTypeArray', 'fldAcctCurrArray',
     'fldDebitAmountUnformatted', 'fldReimbursedAmt', 'fldRemReimburse'].each{|k|
      if body =~/#{k}\[0\]\[0\]=['"]([^'"]*)['"]/
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
    body = post(postdata)

    values= {}
    ['fldEODRunning', 'fldTkApplicable', 'fldAllocationDate', 'fldPaymentDate', 'fldConfirmationDate',
     'fldTransactionDate', 'fldFCISDPRefNo', 'fldSettlementAmt'].each{|k|
      if body =~/#{k}=['"]([^'"]*)['"]/
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
    #res = post(postdata)

    {:method => 'sell_fund' , :amount=>values['fldSettlementAmt'].gsub(',','').to_f,  :alloc_date => values['fldAllocationDate'], :postdata => postdata }
  end

  ##
  # 確定する
  #
  # @param [Hash] data sell_fundやbuy_fundの結果
  def confirm data
    post(data[:postdata])
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
    body = post(postdata)

    parse_array(body, [
      ['fldTxnDateArray', :date],
      ['fldDateAlloted', :alloc_date],
      ['fldRefNoArray', :ref_no],
      ['fldTxnTypeArray', :type],
      ['fldAmountArray', :units, Matchers::PARSE_I ],
      ['fldStlmntAmtFormatted', :amount, Matchers::PARSE_I ],
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
    body = post(postdata)

    uhids = []
    body.scan(/fldTopUHIDArray\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                          uhids[m[1].to_i] = m[2]
    }

    funds = []

    body.scan(/fldFundIDArray\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                         funds[m[1].to_i] = {:id=>m[2], :uhid=>uhids[0]}
    }

    body.scan(/fldFundNameArray\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                           funds[m[1].to_i][:name] = m[2]
    }

    body.scan(/fldFundRiskLevel\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                           funds[m[1].to_i][:risk_level] = m[2].to_i
    }

    body.scan(/fldFundCategoryName\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                              funds[m[1].to_i][:category_name] = m[2]
    }

    body.scan(/fldFundCategory\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                          funds[m[1].to_i][:category] = m[2]
    }

    body.scan(/fldFundURLArray\[(\d+)\]="([^"]+)"/) { m = Regexp.last_match
                                                          funds[m[1].to_i][:url] = m[2]
    }

    funds
  end

  def get_csv_statement(id: nil, from: nil, to: nil)
    id ||= @accounts.keys.first

    today = Date.today
    to ||= today if from

    if to && !from
      raise ArgumentError.new("You need to provide a range start if you provide a range end.")
    elsif from && from > to
      raise ArgumentError.new("Invalid range.")
    elsif from && from < (today - today.day + 1) << 24
      raise ArgumentError.new("You can only go two years in the past.")
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
    post(postdata)

    postdata["fldTxnID"] = "DAA"

    csv = post(postdata).lines[9..-1].join
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
    body = post(postdata)

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

  def getgrid(cell)
    x = cell[0].tr('A-J', '0-9').to_i
    y = cell[1].to_i

    credentials["code_card"][y][x]
  end

  module Matchers
    PARSE_I = lambda { |v| v.gsub(/[,\.]/,'').to_i }.freeze
    PARSE_F = lambda { |v| v.gsub(/,/,'').to_f }.freeze
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

  def post(data)
    @last_res = HTTPClient.new(agent_name: USER_AGENT).post(URL, data)
    @last_html = @last_res.body.toutf8
  end
end

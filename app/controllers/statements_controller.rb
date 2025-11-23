class StatementsController < ApplicationController
  require "nokogiri"
  require "stringio"

  def index
    @statements = Statement.includes(:account).order(created_at: :desc)
  end

  def show
    @statement = Statement.find(params[:id])
  end

  def new
  end

  def create
    uploaded = params.dig(:statement, :file)
    unless uploaded
      redirect_to new_statement_path, alert: "ファイルを選択してください" and return
    end

    doc = Nokogiri::HTML(uploaded.read)

    # メタ情報抽出
    title = doc.at("title")&.text.to_s
    account_number = title[/Statement:\s*(\d+)/, 1]

    header_row = doc.css("table tr").find { |tr| tr.text.include?("Account:") && tr.text.include?("Name:") }
    name = header_row&.text.to_s[/Name:\s*([^\n\r]+)/, 1]&.strip
    currency = header_row&.text.to_s[/Currency:\s*([A-Z]{3})/, 1]

    closed_pl_text = doc.at_xpath("//b[text()='Closed Trade P/L:']/../following-sibling::td/b")&.text.to_s
    balance_text   = doc.at_xpath("//b[text()='Balance:']/../following-sibling::td/b")&.text.to_s
    generated_at_text = header_row&.at("b:last-child")&.text.to_s

    closed_pl = closed_pl_text.gsub(/[^\d\-]/, "").to_i
    balance   = balance_text.gsub(/[^\d\-]/, "").to_i
    generated_at =
      begin
        Time.zone.parse(generated_at_text)
      rescue
        nil
      end

    if account_number.blank? || name.blank?
      redirect_to new_statement_path, alert: "Statement解析に失敗しました（Account/Name）" and return
    end

    account = Account.find_or_initialize_by(number: account_number)
    account.name = name
    account.currency = currency if currency.present?
    account.save!

    statement = account.statements.build(
      uploaded_at: Time.current,
      closed_pl: closed_pl,
      balance: balance,
      raw_generated_at: generated_at
    )
    statement.file.attach(
      io: StringIO.new(doc.to_html),
      filename: "statement_#{account_number}.html",
      content_type: "text/html"
    )
    statement.save!

    # Closed TransactionsをパースしてTrade作成
    trades_attrs = extract_closed_transactions(doc)
    trades_attrs.each do |attrs|
      trade = account.trades.find_or_initialize_by(ticket: attrs[:ticket])
      trade.assign_attributes(attrs.merge(statement_id: statement.id, account_id: account.id))
      trade.save!
    end

    redirect_to account_path(account), notice: "アップロードしました"
  rescue => e
    Rails.logger.error(e.full_message)
    redirect_to new_statement_path, alert: "アップロードに失敗しました"
  end

  private

  def extract_closed_transactions(doc)
    rows = []
    table = doc.at_xpath("//tr[./td/b[contains(text(),'Closed Transactions:')]]/following::tr[1]/ancestor::table")
    return rows unless table

    # ヘッダー行を探す（Ticket〜Profitの行）
    header = table.xpath(".//tr").find do |tr|
      texts = tr.xpath("./td|./th").map { |td| td.text.strip.downcase }
      texts.include?("ticket") && texts.include?("open time") && texts.include?("profit")
    end
    return rows unless header

    # ヘッダー以降のデータ行を走査、次のセクション（Open Trades/Working Ordersなど）で停止
    current = header
    loop do
      current = current.next_element
      break unless current
      txt = current.text.strip
      break if txt.start_with?("Open Trades:", "Working Orders:", "Summary:")
      tds = current.xpath("./td")
      next unless tds.size >= 14

      values = tds.map { |td| td.text.strip }
      # 正規化関数
      to_i = ->(s) { s.to_s.gsub(/[^\d\-]/, "").to_i }
      to_d = ->(s) { s.to_s.gsub(/[^\d\.\-]/, "") }
      to_time = ->(s) { (Time.zone.parse(s) rescue nil) }

      rows << {
        ticket: values[0],
        open_time: to_time.call(values[1]),
        trade_type: values[2],
        size: to_d.call(values[3]),
        item: values[4],
        open_price: to_d.call(values[5]),
        sl: to_d.call(values[6]),
        tp: to_d.call(values[7]),
        close_time: to_time.call(values[8]),
        close_price: to_d.call(values[9]),
        commission: to_i.call(values[10]),
        taxes: to_i.call(values[11]),
        swap: to_i.call(values[12]),
        profit: to_i.call(values[13])
      }
    end

    rows
  end
end

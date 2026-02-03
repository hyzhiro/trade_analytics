class AccountsController < ApplicationController
  def index
    @accounts = Account.order(:name, :number)
  end

  def show
    @account = Account.find(params[:id])
    @trade_types = @account.trades.where.not(trade_type: [nil, ""]).distinct.order(:trade_type).pluck(:trade_type)
    @items = @account.trades.where.not(item: [nil, ""]).distinct.order(:item).pluck(:item)

    # Strong Parametersで許可されたパラメータを取得
    filter_params = params.permit(:from, :to, :type, :item, :per_page, :page, :calendar_month, :commit)

    @trades = @account.trades
    if filter_params[:from].present?
      from_time = Time.zone.parse(filter_params[:from]) rescue nil
      @trades = @trades.where("open_time >= ?", from_time) if from_time
    end
    if filter_params[:to].present?
      to_time = Time.zone.parse(filter_params[:to]) rescue nil
      @trades = @trades.where("open_time <= ?", to_time) if to_time
    end
    if filter_params[:type].present?
      @trades = @trades.where(trade_type: filter_params[:type])
    end
    if filter_params[:item].present?
      @trades = @trades.where(item: filter_params[:item])
    end

    @trades = @trades.order(open_time: :desc, ticket: :desc)

    # ページネーション設定
    @per_page = filter_params[:per_page].present? ? filter_params[:per_page].to_i : 1000
    @per_page = 1000 if @per_page != 100 && @per_page != 1000  # 100または1000のみ許可
    @total_count = @trades.count
    @total_pages = (@total_count.to_f / @per_page).ceil
    @current_page = filter_params[:page].present? ? filter_params[:page].to_i : 1
    @current_page = 1 if @current_page < 1
    @current_page = @total_pages if @current_page > @total_pages && @total_pages > 0

    # ページネーション適用
    @trades = @trades.limit(@per_page).offset((@current_page - 1) * @per_page)

    # 累積損益（開始0基準、横軸=取引回数）をグラフ用に計算
    # グラフ用は全件を使用するため、フィルタ後のクエリから再構築
    all_trades_for_graph = @account.trades
    if filter_params[:from].present?
      from_time = Time.zone.parse(filter_params[:from]) rescue nil
      all_trades_for_graph = all_trades_for_graph.where("open_time >= ?", from_time) if from_time
    end
    if filter_params[:to].present?
      to_time = Time.zone.parse(filter_params[:to]) rescue nil
      all_trades_for_graph = all_trades_for_graph.where("open_time <= ?", to_time) if to_time
    end
    if filter_params[:type].present?
      all_trades_for_graph = all_trades_for_graph.where(trade_type: filter_params[:type])
    end
    if filter_params[:item].present?
      all_trades_for_graph = all_trades_for_graph.where(item: filter_params[:item])
    end
    sorted_for_graph = all_trades_for_graph.reorder(nil).order(Arel.sql("COALESCE(close_time, open_time) ASC"), ticket: :asc)
    cum = 0
    idx = 0
    points = [[0, 0]] # 開始点(取引0件でP/L=0)
    sorted_for_graph.each do |t|
      idx += 1
      cum += t.profit.to_i + t.commission.to_i + t.swap.to_i
      points << [idx, cum]
    end
    @equity_points = points

    # 日別サマリー（カレンダー用）：損益・手数料・スワップ・獲得Pips・損失Pips・ネットPips
    daily_stats = {}
    calendar_min = nil
    calendar_max = nil
    all_trades_for_graph.where.not(close_time: nil).find_each do |t|
      jst = t.close_time_jst
      next unless jst
      d = jst.to_date
      daily_stats[d] ||= { profit: 0, commission: 0, swap: 0, winning_pips: 0.0, losing_pips: 0.0 }
      daily_stats[d][:profit] += t.profit.to_i
      daily_stats[d][:commission] += t.commission.to_i
      daily_stats[d][:swap] += t.swap.to_i
      p = t.pips
      if p.present? && p.abs <= 100_000
        if p > 0
          daily_stats[d][:winning_pips] += p
        else
          daily_stats[d][:losing_pips] += p.abs
        end
      end
      calendar_min = d if calendar_min.nil? || d < calendar_min
      calendar_max = d if calendar_max.nil? || d > calendar_max
    end
    @daily_stats = daily_stats
    if filter_params[:from].present?
      from_date = Date.parse(filter_params[:from]) rescue nil
      calendar_min = from_date if from_date && (calendar_min.nil? || from_date < calendar_min)
    end
    if filter_params[:to].present?
      to_date = Date.parse(filter_params[:to]) rescue nil
      calendar_max = to_date if to_date && (calendar_max.nil? || to_date > calendar_max)
    end
    @calendar_start = calendar_min
    @calendar_end = calendar_max
    # 同日月のみの場合は @calendar_end が nil になり得ないが、念のため
    @calendar_end = @calendar_start if @calendar_end.nil? && @calendar_start

    # 日別カレンダー表示月（2か月分同時表示・ページング用）
    if @calendar_start && @calendar_end
      if filter_params[:calendar_month].present?
        begin
          parts = filter_params[:calendar_month].split("-")
          if parts.size == 2
            y, m = parts[0].to_i, parts[1].to_i
            if (1..12).cover?(m) && y > 0
              candidate = Date.new(y, m, 1)
              # データ範囲内の月のみ有効
              range_start = Date.new(@calendar_start.year, @calendar_start.month, 1)
              range_end = Date.new(@calendar_end.year, @calendar_end.month, 1)
              if candidate >= range_start && candidate <= range_end
                @calendar_display_year = y
                @calendar_display_month = m
              end
            end
          end
        rescue ArgumentError, TypeError
          nil
        end
      end
      unless @calendar_display_year && @calendar_display_month
        # 初期表示: 現在の月と前月（前月が上、今月が下）
        default_first = Date.current.prev_month
        @calendar_display_year = default_first.year
        @calendar_display_month = default_first.month
      end
      display_first = Date.new(@calendar_display_year, @calendar_display_month, 1)
      range_start = Date.new(@calendar_start.year, @calendar_start.month, 1)
      range_end = Date.new(@calendar_end.year, @calendar_end.month, 1)
      # 2か月分: 表示開始月とその翌月（上＝先の月、下＝後の月）
      display_second = display_first.next_month
      @calendar_display_months = [
        [display_first.year, display_first.month],
        [display_second.year, display_second.month]
      ]
      # ナビは1か月ずつ: 前月＝表示の1か月前、次月＝表示の1か月後
      @calendar_prev_month = (display_first > range_start) ? display_first.prev_month : nil
      @calendar_next_month = (display_second <= range_end) ? display_second : nil
    end

    # 月別サマリー（カレンダー下の表・グラフ用）：損益・手数料・スワップ・収支・獲得Pips・損失Pips・ネットPips
    monthly = {}
    daily_stats.each do |d, s|
      key = [d.year, d.month]
      monthly[key] ||= { profit: 0, commission: 0, swap: 0, winning_pips: 0.0, losing_pips: 0.0 }
      monthly[key][:profit] += s[:profit]
      monthly[key][:commission] += s[:commission]
      monthly[key][:swap] += s[:swap]
      monthly[key][:winning_pips] += s[:winning_pips]
      monthly[key][:losing_pips] += s[:losing_pips]
    end
    @monthly_stats = monthly.sort_by { |(y, m), _| [y, m] }.map do |(year, month), s|
      balance = s[:profit] + s[:commission] + s[:swap]
      {
        year: year,
        month: month,
        label: "#{year}年#{month}月",
        profit: s[:profit],
        commission: s[:commission],
        swap: s[:swap],
        balance: balance,
        winning_pips: s[:winning_pips].round(1),
        losing_pips: s[:losing_pips].round(1),
        net_pips: (s[:winning_pips] - s[:losing_pips]).round(1)
      }
    end

    # Type別の割合（円グラフ用）
    type_counts = all_trades_for_graph.where.not(trade_type: [nil, ""])
                                     .group(:trade_type)
                                     .count
    @type_distribution = type_counts.map { |type, count| { type: type, count: count } }

    # 曜日ごとの勝率（日本時間で分析）
    weekday_stats = {}
    all_trades_for_graph.where.not(open_time: nil).find_each do |t|
      # MT4時間を日本時間に変換
      jst_time = t.open_time_jst
      next unless jst_time
      weekday = jst_time.wday # 0=日曜日, 1=月曜日, ..., 6=土曜日
      weekday_name = %w[日 月 火 水 木 金 土][weekday]
      weekday_stats[weekday_name] ||= { total: 0, wins: 0 }
      weekday_stats[weekday_name][:total] += 1
      weekday_stats[weekday_name][:wins] += 1 if t.profit.to_f > 0
    end
    @weekday_win_rates = weekday_stats.map do |day, stats|
      {
        day: day,
        win_rate: stats[:total] > 0 ? (stats[:wins].to_f / stats[:total] * 100).round(1) : 0,
        total: stats[:total],
        wins: stats[:wins]
      }
    end.sort_by { |h| %w[日 月 火 水 木 金 土].index(h[:day]) || 99 }

    # 時間帯ごとの勝率（1時間ごと、日本時間で分析）
    hour_stats = {}
    all_trades_for_graph.where.not(open_time: nil).find_each do |t|
      # MT4時間を日本時間に変換
      jst_time = t.open_time_jst
      next unless jst_time
      hour = jst_time.hour
      hour_stats[hour] ||= { total: 0, wins: 0 }
      hour_stats[hour][:total] += 1
      hour_stats[hour][:wins] += 1 if t.profit.to_f > 0
    end
    @hour_win_rates = (0..23).map do |hour|
      stats = hour_stats[hour] || { total: 0, wins: 0 }
      {
        hour: hour,
        hour_label: "#{hour}時",
        win_rate: stats[:total] > 0 ? (stats[:wins].to_f / stats[:total] * 100).round(1) : 0,
        total: stats[:total],
        wins: stats[:wins]
      }
    end

    # 通貨ペアごとの勝率
    item_stats = {}
    all_trades_for_graph.where.not(item: [nil, ""]).find_each do |t|
      item = t.item
      item_stats[item] ||= { total: 0, wins: 0 }
      item_stats[item][:total] += 1
      item_stats[item][:wins] += 1 if t.profit.to_f > 0
    end
    @item_win_rates = item_stats.map do |item, stats|
      {
        item: item,
        win_rate: stats[:total] > 0 ? (stats[:wins].to_f / stats[:total] * 100).round(1) : 0,
        total: stats[:total],
        wins: stats[:wins]
      }
    end.sort_by { |h| -h[:win_rate] } # 勝率の高い順にソート

    # 統計情報の計算
    all_trades_for_stats = all_trades_for_graph
    total_trades = all_trades_for_stats.count
    winning_trades = all_trades_for_stats.select { |t| t.win? }
    losing_trades = all_trades_for_stats.select { |t| t.loss? }

    # 平均獲得Pips数（勝ちトレードのみ）
    winning_pips = winning_trades.map { |t| t.pips }.compact.reject { |p| p.nil? || p.abs > 100000 }
    @average_winning_pips = winning_pips.any? ? (winning_pips.sum.to_f / winning_pips.size).round : 0

    # 平均損失Pips数（負けトレードのみ、絶対値）
    # 負けトレードのPipsは負の値になるはずなので、絶対値を取る
    losing_pips = losing_trades.map { |t| t.pips }.compact.reject { |p| p.nil? || p.abs > 100000 }.map(&:abs)
    @average_losing_pips = losing_pips.any? ? (losing_pips.sum.to_f / losing_pips.size).round : 0

    # 総トレード回数
    @total_trades_count = total_trades

    # 勝ちトレード数
    @winning_trades_count = winning_trades.size

    # 負けトレード数
    @losing_trades_count = losing_trades.size

    # リスクリワード比率
    if @average_losing_pips > 0
      @risk_reward_ratio = (@average_winning_pips / @average_losing_pips).round(1)
    else
      @risk_reward_ratio = @average_winning_pips > 0 ? Float::INFINITY : 0
    end
  end
end

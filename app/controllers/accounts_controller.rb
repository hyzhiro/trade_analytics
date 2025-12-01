class AccountsController < ApplicationController
  def index
    @accounts = Account.order(:name, :number)
  end

  def show
    @account = Account.find(params[:id])
    @trade_types = @account.trades.where.not(trade_type: [nil, ""]).distinct.order(:trade_type).pluck(:trade_type)
    @items = @account.trades.where.not(item: [nil, ""]).distinct.order(:item).pluck(:item)

    # Strong Parametersで許可されたパラメータを取得
    filter_params = params.permit(:from, :to, :type, :item, :per_page, :page, :commit)

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
      cum += t.profit.to_i
      points << [idx, cum]
    end
    @equity_points = points

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
    @average_winning_pips = winning_pips.any? ? (winning_pips.sum.to_f / winning_pips.size).round(1) : 0
    
    # 平均損失Pips数（負けトレードのみ、絶対値）
    # 負けトレードのPipsは負の値になるはずなので、絶対値を取る
    losing_pips = losing_trades.map { |t| t.pips }.compact.reject { |p| p.nil? || p.abs > 100000 }.map(&:abs)
    @average_losing_pips = losing_pips.any? ? (losing_pips.sum.to_f / losing_pips.size).round(1) : 0
    
    # 総トレード回数
    @total_trades_count = total_trades
    
    # 勝ちトレード数
    @winning_trades_count = winning_trades.size
    
    # 負けトレード数
    @losing_trades_count = losing_trades.size
    
    # リスクリワード比率
    if @average_losing_pips > 0
      @risk_reward_ratio = (@average_winning_pips / @average_losing_pips).round(2)
    else
      @risk_reward_ratio = @average_winning_pips > 0 ? Float::INFINITY : 0
    end
  end
end

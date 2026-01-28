class Trade < ApplicationRecord
  belongs_to :statement
  belongs_to :account

  # MT4の現地時間を日本時間に変換
  # 夏時間（3月第2日曜日〜11月第1日曜日）: +6時間
  # 冬時間（11月第1日曜日〜3月第2日曜日）: +7時間
  def open_time_jst
    return nil unless open_time
    convert_mt4_to_jst(open_time)
  end

  def close_time_jst
    return nil unless close_time
    convert_mt4_to_jst(close_time)
  end

  # Pipsを計算
  def pips
    return nil unless open_price && close_price && item
    return nil if open_price.to_f == 0 || close_price.to_f == 0

    # 通貨ペアに応じてpip_valueを決定
    pip_value = pip_value_for_item

    # 価格差を計算
    price_diff = close_price.to_f - open_price.to_f

    # Buy/Sellに応じて符号を調整
    # Buy: 価格上昇で利益（正）、価格下降で損失（負）
    # Sell: 価格下降で利益（正）、価格上昇で損失（負）
    multiplier = buy? ? 1 : -1

    (price_diff / pip_value * multiplier).round
  end

  # 通貨ペアに応じたpip_valueを取得
  def pip_value_for_item
    return 0.0001 unless item
    
    item_upper = item.upcase.strip
    
    # XAUUSD（ゴールド）の判定
    # 様々な表記に対応（XAUUSD, GOLD, GOLDMICRO, XAU/USDなど）
    if item_upper == "XAUUSD" || item_upper == "GOLD" || 
       item_upper.start_with?("XAU") || item_upper.include?("XAUUSD") ||
       item_upper.include?("GOLD")
      0.1  # XAUUSD: 0.1ドル = 1Pips
    # BTCUSD（ビットコイン）の判定
    # 様々な表記に対応（BTCUSD, BTC/USD, BITCOINなど）
    elsif item_upper == "BTCUSD" || item_upper == "BTC/USD" || 
          item_upper.start_with?("BTC") || item_upper.include?("BTCUSD") ||
          item_upper.include?("BITCOIN")
      10.0  # BTCUSD: 10ドル = 1Pips
    # JPN225（日経225）の判定
    # 様々な表記に対応（JPN225, N225, NIKKEI225など）
    elsif item_upper == "JPN225" || item_upper == "N225" || 
          item_upper == "NIKKEI225" || item_upper.include?("JPN225") ||
          item_upper.include?("N225") || item_upper.include?("NIKKEI")
      10.0  # JPN225: 10円 = 1Pips
    elsif jpy_pair?
      0.01  # JPYペア: 0.01 = 1Pips
    else
      0.0001  # その他の通貨ペア: 0.0001 = 1Pips
    end
  end

  # Buyトレードかどうか
  def buy?
    trade_type&.upcase == "BUY"
  end

  # Sellトレードかどうか
  def sell?
    trade_type&.upcase == "SELL"
  end

  # JPYペアかどうか
  def jpy_pair?
    return false unless item
    item.upcase.include?("JPY")
  end

  # XAUUSD（ゴールド）かどうか
  def xauusd?
    return false unless item
    item_upper = item.upcase.strip
    item_upper == "XAUUSD" || item_upper == "GOLD" || 
    item_upper.include?("XAU") || item_upper.include?("GOLD")
  end

  # BTCUSD（ビットコイン）かどうか
  def btcusd?
    return false unless item
    item_upper = item.upcase.strip
    item_upper == "BTCUSD" || item_upper == "BTC/USD" || 
    item_upper.start_with?("BTC") || item_upper.include?("BTCUSD") ||
    item_upper.include?("BITCOIN")
  end

  # JPN225（日経225）かどうか
  def jpn225?
    return false unless item
    item_upper = item.upcase.strip
    item_upper == "JPN225" || item_upper == "N225" || 
    item_upper == "NIKKEI225" || item_upper.include?("JPN225") ||
    item_upper.include?("N225") || item_upper.include?("NIKKEI")
  end

  # 勝ちトレードかどうか
  def win?
    profit.to_f > 0
  end

  # 負けトレードかどうか
  def loss?
    profit.to_f < 0
  end

  private

  # MT4時間を日本時間に変換
  def convert_mt4_to_jst(mt4_time)
    # 夏時間かどうかを判定（3月第2日曜日から11月第1日曜日まで）
    offset_hours = daylight_saving_time?(mt4_time) ? 6 : 7
    mt4_time + offset_hours.hours
  end

  # 指定された日時が夏時間（Daylight Saving Time）かどうかを判定
  # 北米の夏時間: 3月第2日曜日 02:00 から 11月第1日曜日 02:00 まで
  def daylight_saving_time?(time)
    year = time.year
    march_second_sunday = find_nth_sunday(year, 3, 2)
    november_first_sunday = find_nth_sunday(year, 11, 1)

    # 3月第2日曜日 02:00 以降
    dst_start = march_second_sunday.change(hour: 2, min: 0, sec: 0)
    # 11月第1日曜日 02:00 以降
    dst_end = november_first_sunday.change(hour: 2, min: 0, sec: 0)

    # 11月第1日曜日が3月第2日曜日より前の場合は、次の年の3月第2日曜日まで
    if dst_end < dst_start
      time >= dst_start || time < dst_end
    else
      time >= dst_start && time < dst_end
    end
  end

  # 指定された年月の第N日曜日を取得（Timeオブジェクトとして返す）
  def find_nth_sunday(year, month, nth)
    # 月の最初の日
    first_day = Date.new(year, month, 1)
    # 最初の日曜日を探す
    first_sunday = first_day + (7 - first_day.wday) % 7
    # 第N日曜日をTimeオブジェクトに変換
    (first_sunday + (nth - 1) * 7).to_time
  end
end



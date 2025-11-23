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



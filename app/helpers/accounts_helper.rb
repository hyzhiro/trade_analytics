module AccountsHelper
  # 指定月のカレンダー週（日曜始まり）を返す。各要素は [nil | Date] の7要素の配列の配列。
  def calendar_weeks_for_month(year, month)
    first = Date.new(year, month, 1)
    last = first.end_of_month
    start_offset = first.wday
    arr = Array.new(start_offset, nil)
    (first..last).each { |d| arr << d }
    remain = arr.size % 7
    arr += Array.new(remain == 0 ? 0 : 7 - remain, nil)
    arr.each_slice(7).to_a
  end
end

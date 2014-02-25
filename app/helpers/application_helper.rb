module ApplicationHelper

  def get_request_count(type,array)
    count = 0
    array.each do |ele|
      count = count.next if ele.eql?(type)
    end
    count
  end

  def percent_of(val1, val2)
  	"#{((val1.to_f/val2.to_f)*100).round(2)} %"
  end

end

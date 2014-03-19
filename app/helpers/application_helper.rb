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

  def convert_to_days(seconds)
    "#{(seconds/60/60/24).round(1)}"
  end

  def convert_to_hours(seconds)
    "#{(seconds/60/60/8).round(2)}"
  end
  
  def get_inprocess_defects(defect_counts)
    defect_counts['Review Defect'] + defect_counts['Testing Defect']
  end

  def get_defect_removal_efficiency(val1,val2,val3)
    "#{((val1*100)/(val2+val3))} %"
  end

end

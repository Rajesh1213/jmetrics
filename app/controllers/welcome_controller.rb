class WelcomeController < ApplicationController
  before_filter :authenticate_user!
  
  def index
    puts "params.. #{params.inspect}"
    if params[:from_date].present? && params[:to_date].present?
      from_date = get_date(params[:from_date])
      to_date = get_date(params[:to_date])
      puts "from_date... #{from_date}"
      puts "to_date..#{to_date}"
    else
      from_date = Time.now.strftime("%Y-%m-%d")
      to_date = Time.now.strftime("%Y-%m-%d")
    end
    
    puts "from_date..#{from_date}"
    puts "to_date..#{to_date}"
    #total_work_req_assigned
    response = post_search('search','{"jql":"project=UT AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029","fields":["id","key"]}}')
    parsed_response=JSON.parse(response)
    @work_req_assigned = parsed_response['total']

    #work reqst committed
    response = post_search('search','{"jql":"project=UT AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029 AND duedate IS NOT EMPTY","fields":["id","key","duedate","resolutiondate","issuetype","customfield_10024"]}}')
    parsed_response=JSON.parse(response)

    @work_req_committed = parsed_response['total']
    issues_committed = parsed_response['issues']

    @work_req_delayed = 0
    @work_req_on_time = 0
    @work_req_not_delivered = 0
    complexity = []
    @complexity_requests_hash = Hash.new

    issues_committed.each do |issue|
      if issue['fields']['resolutiondate']
        resol_date = Time.parse(issue['fields']['resolutiondate'])
        due_date = Time.parse(issue['fields']['duedate'])
        complexity << issue['fields']['customfield_10024']['value']
        puts "issue['fields']['issuetype']['name']............. #{issue['fields']['issuetype']['name']}"
        puts "issue['fields']['customfield_10024']['value']..... #{issue['fields']['customfield_10024']['value']}"
        issuetype = issue['fields']['issuetype']['name']
        @complexity_requests_hash[issue['fields']['customfield_10024']['value']] = @complexity_requests_hash[issue['fields']['customfield_10024']['value']].blank? ? 
                                                                                   [issuetype] : 
                                                                                   @complexity_requests_hash[issue['fields']['customfield_10024']['value']] + [issuetype]
        
        if resol_date > due_date
          @work_req_delayed += 1
        elsif resol_date <= due_date
          @work_req_on_time += 1
        end
      else
        @work_req_not_delivered += 1
      end
    end
    puts "@complexity_requests_hash... #{@complexity_requests_hash}"
    @total_work_req_delivered = @work_req_on_time + @work_req_delayed
    @complexity_counts = Hash.new(0)
    puts "complexity... #{complexity}"
    complexity.each { |name| @complexity_counts[name] += 1 }
    puts "complexity_counts... #{@complexity_counts}"
  end

end

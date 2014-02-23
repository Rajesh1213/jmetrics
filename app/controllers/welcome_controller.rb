class WelcomeController < ApplicationController
  before_filter :authenticate_user!
  
  def index
    #total_work_req_assigned
    response = post_search('search','{"jql":"project=UT AND created>=2014-01-01 AND created<=2014-01-30 AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029","fields":["id","key"]}}')
    parsed_response=JSON.parse(response)
    @work_req_assigned = parsed_response['total']
    puts "work_req_assigned... #{@work_req_assigned}"

    #work reqst committed
    response = post_search('search','{"jql":"project=UT AND created>=2014-01-01 AND created<=2014-01-30 AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029 AND duedate IS NOT EMPTY","fields":["id","key","duedate","resolutiondate"]}}')
    parsed_response=JSON.parse(response)
    @work_req_committed = parsed_response['total']
    puts "work_req_commited.. #{@work_req_committed}"

    issues_committed = parsed_response['issues']

    @work_req_delayed = 0
    @work_req_on_time = 0
    @work_req_not_delivered = 0

    issues_committed.each do |issue|
      if issue['fields']['resolutiondate']
        resol_date = Time.parse(issue['fields']['resolutiondate'])
        due_date = Time.parse(issue['fields']['duedate'])
        if resol_date > due_date
        @work_req_delayed += 1
        elsif resol_date <= due_date
        @work_req_on_time += 1
        end
      else
        @work_req_not_delivered += 1
      end
    end
    @total_work_req_delivered = @work_req_on_time + @work_req_delayed

    puts "work_req_on_time... #{@work_req_on_time}"
    puts "work_req_delayed.. #{@work_req_delayed}"
    puts "work_req_not_delivered... #{@work_req_not_delivered}"
    puts "total work req delievered.. #{@total_work_req_delivered}"

  end

end

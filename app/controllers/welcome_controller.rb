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
    response = post_search('search','{"jql":"project=UT AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029 AND duedate IS NOT EMPTY","fields":["id","key","duedate","resolutiondate","issuetype","customfield_10024","timespent"]}}')
    parsed_response=JSON.parse(response)
    puts "parsed_response...#{parsed_response}"

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
          puts "issue['key'].. #{issue['key']}   . #{issue['fields']['timespent']}"
        elsif resol_date <= due_date
          puts "issue['key']...#{issue['key']}....... #{issue['fields']['timespent']}"
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


  def delivery_management_effectiveness
    #work reqst committed
    response = post_search('search','{"jql":"project=UT AND created>=2014-01-01 AND created<=2014-01-30 AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029 AND duedate IS NOT EMPTY","fields":["id","key","duedate","resolutiondate","issuetype","customfield_10024","timespent"]}}')
    parsed_response=JSON.parse(response)
#    puts "parsed_response...#{parsed_response}"
    
    issues_committed = parsed_response['issues']
    @total_work_requests_delivered = []
    issues_committed.each do |issue|
      if issue['fields']['resolutiondate']
        resol_date = Time.parse(issue['fields']['resolutiondate'])
        due_date = Time.parse(issue['fields']['duedate'])

        if resol_date > due_date || resol_date <= due_date
           @total_work_requests_delivered << issue
           sub_tasks = get_sub_tasks(issue['key'])
           sub_tasks.each do |sub_task|
             @total_work_requests_delivered << sub_task
           end
        end
      end
    end
    @complexity_cycle_hash = get_delivery_cycle_data(@total_work_requests_delivered)
    puts "@complexity_cycle_hash... #{@complexity_cycle_hash}"
#    get_delivery_effort_data(@total_work_requests_delivered)
  end

  #returns {'high'=>[min,max,avg]}
  def get_delivery_cycle_data(total_work_requests_delivered)
   all_complex_issues = get_all_complex_issues(total_work_requests_delivered)
   complexity_cycle_hash = {}

   all_complex_issues.each_key do |key|
    complex_cycle = all_complex_issues[key].map{|ele| ele['fields']['timespent']}
    complexity_cycle_hash[key] = [complex_cycle.min, complex_cycle.max, (complex_cycle.sum/complex_cycle.count)]
   end
   return complexity_cycle_hash
  end

  #returns hash
  def get_all_complex_issues(total_work_requests_delivered)
    all_complex_issues = {}
    total_work_requests_delivered.each do |issue|
      if issue['fields']['customfield_10024'].present?
        puts "inside... all_complex_issues[issue['fields']['customfield_10024']['value']]"
        all_complex_issues[issue['fields']['customfield_10024']['value']] = all_complex_issues[issue['fields']['customfield_10024']['value']].blank? ?
                                                                                   [issue] :
                                                                                   all_complex_issues[issue['fields']['customfield_10024']['value']] + [issue]
      end
    end
    all_complex_issues
  end

  def get_sub_tasks(parent_key)
    sub_tasks = post_search('search','{"jql":"project=UT AND created>=2014-01-01 AND created<=2014-01-30 AND duedate IS NOT EMPTY AND parent = '"#{parent_key}"'","fields":["id","key","customfield_10024","timespent"]}}')
    sub_tasks = JSON.parse(sub_tasks)
    sub_tasks['issues']
  end

end

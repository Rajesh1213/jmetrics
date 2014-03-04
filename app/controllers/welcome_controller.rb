class WelcomeController < ApplicationController
  before_filter :authenticate_user!
  
  def index
    if params[:from_date].present? && params[:to_date].present? &&  params[:Project]
      from_date = get_date(params[:from_date])
      to_date = get_date(params[:to_date])
      project = params[:Project]
    else
      from_date = Time.now.strftime("%Y-%m-%d")
      to_date = Time.now.strftime("%Y-%m-%d")
      project = 'UT'
    end
    
    #total_work_req_assigned
    response = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029","fields":["id","key"]}}')
    parsed_response=JSON.parse(response)    
    @work_req_assigned = parsed_response['total']

    #work reqst committed
    response = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029 AND duedate IS NOT EMPTY","fields":["id","key","duedate","resolutiondate","issuetype","customfield_10024","timespent"]}}')
    parsed_response = JSON.parse(response)
    total = parsed_response['total']
    @total_work_requests_committed = []

    #get sub-tasks of all tasks
    parsed_response['issues'].each do |issue|
      @total_work_requests_committed << issue
      sub_tasks = get_sub_tasks(from_date, to_date, issue['key'], project)
      @total_work_requests_committed << sub_tasks if sub_tasks.present?
    end


    @total_work_requests_committed = @total_work_requests_committed.flatten
    @work_req_committed = @total_work_requests_committed.count

    @work_req_delayed = 0
    @work_req_on_time = 0
    @work_req_not_delivered = 0
    complexity = []
    @complexity_requests_hash = Hash.new

    @total_work_requests_committed.each do |issue|
      if issue['fields']['resolutiondate']
        resol_date = Time.parse(issue['fields']['resolutiondate'])
        due_date = Time.parse(issue['fields']['duedate'])
        issuetype = issue['fields']['issuetype']['name']
        issue_complexity = issue['fields']['customfield_10024'].present? ? issue['fields']['customfield_10024']['value'] : 'Low'

        complexity << issue_complexity
        @complexity_requests_hash[issue_complexity] = @complexity_requests_hash[issue_complexity].blank? ? 
                                                                                   [issuetype] : 
                                                                                   @complexity_requests_hash[issue_complexity] + [issuetype]
        
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
    @complexity_counts = Hash.new(0)
    complexity.each { |name| @complexity_counts[name] += 1 }
  end

  #customfield_10042 -> task started date
  def delivery_management_effectiveness
    #work reqst committed
    response = post_search('search','{"jql":"project=UT AND created>=2014-01-01 AND created<=2014-01-31 AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029 AND duedate IS NOT EMPTY","fields":["id","key","duedate","resolutiondate","issuetype","customfield_10024","timespent","customfield_10042"]}}')
    parsed_response=JSON.parse(response)
    
    issues_committed = parsed_response['issues']
    @total_work_requests_committed = []
    @total_work_requests_delivered = []

    #get sub-tasks of all tasks
    parsed_response['issues'].each do |issue|
      @total_work_requests_committed << issue
      sub_tasks = get_sub_tasks("2014-01-01", "2014-01-31", issue['key'], 'UT')
      @total_work_requests_committed << sub_tasks if sub_tasks.present?
    end

    @total_work_requests_committed = @total_work_requests_committed.flatten

    @total_work_requests_committed.each do |issue|
      if issue['fields']['resolutiondate']
        resol_date = Time.parse(issue['fields']['resolutiondate'])
        due_date = Time.parse(issue['fields']['duedate'])

        @total_work_requests_delivered << issue if (resol_date > due_date || resol_date <= due_date)
      end
    end
    @total_work_requests_delivered = @total_work_requests_delivered.flatten
    all_complex_issues = get_all_complex_issues(@total_work_requests_delivered)

    @complexity_cycle_hash = get_delivery_cycle_data(all_complex_issues)
    puts "@complexity_cycle_hash.. #{@complexity_cycle_hash}"
    @complexity_effort_hash = get_delivery_effort_data(all_complex_issues)
    puts "@complexity_effort_hash... #{@complexity_effort_hash}"

  end

  #returns {'high'=>[min,max,avg]} in seconds. use a helper in view to convert to days/hrs
  def get_delivery_cycle_data(all_complex_issues)
    complexity_cycle_hash = {}

    all_complex_issues.each_pair do |key,value|
      cycle_time = all_complex_issues[key].map{|ele| get_cycle_time(ele['fields']['resolutiondate'], ele['fields']['customfield_10042']) }
      complexity_cycle_hash[key] = [cycle_time.min,cycle_time.max,cycle_time.sum/cycle_time.count]
    end
    return complexity_cycle_hash
  end

  def get_delivery_effort_data(all_complex_issues)
    complexity_effort_hash = {}

    all_complex_issues.each_pair do |key,value|
      # get_cycle_time(key,value)
      effort_time = all_complex_issues[key].map{|ele| ele['fields']['timespent']}
      complexity_effort_hash[key] = [effort_time.min,effort_time.max,effort_time.sum/effort_time.count]
    end
    return complexity_effort_hash
  end

  def get_cycle_time(resolution_date, start_date)
    Time.parse(resolution_date) - Time.parse(start_date)
  end

  #returns hash
  def get_all_complex_issues(total_work_requests_delivered)
    all_complex_issues = {}
    total_work_requests_delivered.each do |issue|
      if issue['fields']['customfield_10024'].present?
        all_complex_issues[issue['fields']['customfield_10024']['value']] = all_complex_issues[issue['fields']['customfield_10024']['value']].blank? ?
                                                                                   [issue] :
                                                                                   all_complex_issues[issue['fields']['customfield_10024']['value']] + [issue]
      end
    end
    all_complex_issues
  end

  def get_sub_tasks(from_date, to_date, parent_key, project)
    sub_tasks = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND duedate IS NOT EMPTY AND parent = '"#{parent_key}"'","fields":["id","key","duedate","resolutiondate","issuetype","customfield_10024","timespent"]}}')
    sub_tasks = JSON.parse(sub_tasks)
    sub_tasks['issues']
  end

end
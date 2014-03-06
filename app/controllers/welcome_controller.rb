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
    @work_req_assigned = parsed_response['issues']

    #work reqst committed
    response = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029 AND duedate IS NOT EMPTY"}}')
    parsed_response = JSON.parse(response)
    total = parsed_response['total']
    @total_work_requests_committed = parsed_response['issues']
    @work_req_committed = @total_work_requests_committed

    @work_req_delayed = []
    @work_req_on_time = []
    @work_req_not_delivered = []
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
          @work_req_delayed << issue
        elsif resol_date <= due_date
          @work_req_on_time << issue
        end
      else
        @work_req_not_delivered << issue
      end
    end

    @total_work_req_delivered = @work_req_on_time + @work_req_delayed
    @complexity_counts = Hash.new(0)
    complexity.each { |name| @complexity_counts[name] += 1 }

    # delivery_management_effectiveness
    all_complex_issues = get_all_complex_issues(@total_work_req_delivered)
    #development effectiveness
    @development_effectiveness = get_development_effectiveness(@total_work_req_delivered, project)
    @complexity_cycle_hash = get_delivery_cycle_data(all_complex_issues)
    @complexity_effort_hash = get_delivery_effort_data(all_complex_issues)
  end

  def get_delivered_requests(total_work_requests_committed)
    total_work_requests_delivered = []
    total_work_requests_committed.each do |issue|
      if issue['fields']['resolutiondate']
        resol_date = Time.parse(issue['fields']['resolutiondate'])
        due_date = Time.parse(issue['fields']['duedate'])

        total_work_requests_delivered << issue if (resol_date > due_date || resol_date <= due_date)
      end
    end
    total_work_requests_delivered
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

  def get_development_effectiveness(total_work_requests_delivered, project)
    issue_parent_ids = []
    total_work_requests_delivered.map{|issue| issue_parent_ids << issue['key'] }
    parent_ids = issue_parent_ids.map { |i| "'" + i.to_s + "'" }.join(",")
    testing_sub_tasks =  get_testing_tasks(parent_ids, project)
    puts "testing subtasks = #{testing_sub_tasks.inspect}"
  end

  def get_sub_tasks(from_date, to_date, parent_key, project)
    sub_tasks = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND duedate IS NOT EMPTY AND parent = '"#{parent_key}"'","fields":["id","key","duedate","resolutiondate","issuetype","customfield_10024","timespent"]}}')
    sub_tasks = JSON.parse(sub_tasks)
    sub_tasks['issues']
  end

  def get_testing_tasks(issue_parent_ids,project)
    testing_tasks = post_search('search', '{"jql":"project='"#{project}"' AND type = Testing\\\u0020Task AND parent in \\u0028'"#{issue_parent_ids}"'\\u0029 "}')
  end

end
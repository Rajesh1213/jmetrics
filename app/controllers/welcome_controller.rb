class WelcomeController < ApplicationController
  before_filter :build_hash
  def index
    if request.post? && params[:from_date].present? && params[:to_date].present? && params[:Project].present?
      from_date = get_date(params[:from_date])
      to_date = get_date(params[:to_date])
      project = params[:Project]
      @project = params[:Project]

      #total_work_req_assigned
      # response = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\u002CDelivered\\\u0020Defect\\u002CNew\\\u0020Requirement\\u0029","fields":["id","key"]}}')
      response = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\\u0020\\\u0028NWF\\\u0029\\u002CDelivered\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u002CNew\\\u0020Requirement\\\u0020\\\u0028NWF\\\u0029\\u0029","startAt":0,"maxResults":1000,"fields":["id","key"]}}')
      parsed_response=JSON.parse(response)
      @work_req_assigned = parsed_response['issues']
      #work reqst committed
      response = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Change\\\u0020Request\\\u0020\\\u0028NWF\\\u0029\\u002CDelivered\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u002CNew\\\u0020Requirement\\\u0020\\\u0028NWF\\\u0029\\u0029 AND duedate IS NOT EMPTY","startAt":0,"maxResults":1000}}')
      parsed_response = JSON.parse(response)
      total = parsed_response['total']
      @total_work_requests_committed = parsed_response['issues']
      @work_req_committed = @total_work_requests_committed
      # work_request_delivery_cycle_time
      work_request_delivery_cycle_time(@total_work_requests_committed)
      # delivery_management_effectiveness
      all_complex_issues = get_all_complex_issues(@total_work_req_delivered)
      #development effectiveness
      @development_effectiveness = @total_work_req_delivered.present? ? get_development_effectiveness(@total_work_req_delivered, project) : 0
      @complexity_cycle_hash = get_delivery_cycle_data(all_complex_issues)
      @complexity_effort_hash = get_delivery_effort_data(all_complex_issues)
      #development effectiveness
      get_development_effectiveness_defects(project, from_date, to_date)

      #Percentage Distribution of Efforts
      get_percentage_distribution_efforts(@total_work_req_delivered, project, from_date, to_date)
    else
      render :template => 'welcome/index'
    end
  end

  def get_percentage_distribution_efforts(total_work_req_delivered, project, from_date, to_date)
    @analysis_effort = 0

    @solution_design_effort = 0
    @testcase_design_effort = 0
    @total_design_phase_effort = 0

    @analysis_review_effort = 0
    @solution_design_review_effort = 0
    @testcase_review_effort = 0
    @code_review_effort = 0
    @total_review_phase_effort = 0

    @development_effort = 0

    @peer_functional_testing_effort = 0
    @prerelease_qa_testing_effort = 0
    @total_testing_phase_effort = 0

    total_work_req_delivered.each do |issue|
      @analysis_effort += get_analysis_effort(issue)

      design_effort = get_design_effort(issue)
      @solution_design_effort += design_effort[0]
      @testcase_design_effort += design_effort[1]
      @total_design_phase_effort += design_effort[2]

      review_effort = get_review_effort(issue)
      @analysis_review_effort += review_effort[0]
      @solution_design_review_effort += review_effort[1]
      @testcase_review_effort += review_effort[2]
      @code_review_effort += review_effort[3]
      @total_review_phase_effort += review_effort[4]

      @development_effort += get_development_effort(issue)

      testing_effort = get_testing_effort(issue)
      @peer_functional_testing_effort += testing_effort[0]
      @prerelease_qa_testing_effort += testing_effort[1]
      @total_testing_phase_effort += testing_effort[2]

    end

    #defect_fix_effort in hours
    @defect_fix_effort = get_defect_fix_effort(project, from_date, to_date)

    @total_effort = @analysis_effort + @total_design_phase_effort + @total_review_phase_effort + @development_effort + @total_testing_phase_effort + @defect_fix_effort
  end

  def get_defect_fix_effort(project, from_date, to_date)
    #issuetype in ("Req: Delivered Defect (NWF)","Data Defect","Test Case Review Defect (NWF)","Testing Defect (NWF)","Review Defect (NWF)")
    defects = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Test\\\u0020Case\\\u0020Review\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u002CReview\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u002CTesting\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u002CReq\\\u003A\\\u0020Delivered\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u002CData\\\u0020Defect\\u0029 AND duedate IS NOT EMPTY","startAt":0,"maxResults":1000}}')
    defects = parsed_response=JSON.parse(defects)['issues']
    time_spent = defects.map{|defect| defect['fields']['timespent']}.sum
    (time_spent.to_f/3600.to_f).round(2)
  end

  def get_testing_effort(issue)
    peer_functional_testing_keys = [t(:Peer_Functional_Testing_Effort)]
    prerelease_qa_testing_keys = [t(:Pre_Release_QA_Testing_Effort)]

    peer_functional_testing_effort = get_sum(peer_functional_testing_keys,issue)
    prerelease_qa_testing_effort = get_sum(prerelease_qa_testing_keys,issue)
    total_testing_phase_effort = peer_functional_testing_effort + prerelease_qa_testing_effort

    [peer_functional_testing_effort, prerelease_qa_testing_effort, total_testing_phase_effort]
  end

  def get_development_effort(issue)
    coding_keys = [t(:Coding_Effort)]
    get_sum(coding_keys, issue)
  end

  def get_review_effort(issue)
    analysis_review_keys = [t(:Analysis_Review_Effort)]
    solution_design_review_keys = [t(:Design_Review_Effort)]
    testcase_review_keys = [t(:Test_Review_Effort_for_QA),t(:Test_Review_Effort_for_Unit_testing)]
    code_review_keys = [t(:Code_Review_Effort)]

    analysis_review_effort = get_sum(analysis_review_keys, issue)
    solution_design_review_effort = get_sum(solution_design_review_keys, issue)
    testcase_review_effort = get_sum(testcase_review_keys, issue)
    code_review_effort = get_sum(code_review_keys, issue)
    total_review_phase_effort = analysis_review_effort + solution_design_review_effort + testcase_review_effort + code_review_effort

    [analysis_review_effort, solution_design_review_effort, testcase_review_effort, code_review_effort, total_review_phase_effort]
  end

  def get_design_effort(issue)
    solution_design_keys = [t(:Design_Effort)]
    testcase_design_effort_keys = [t(:Test_Case_Design_Effort)]

    solution_design_effort = get_sum(solution_design_keys, issue)
    testcase_design_effort = get_sum(testcase_design_effort_keys, issue)
    total_design_phase_effort = solution_design_effort + testcase_design_effort
    
    [solution_design_effort, testcase_design_effort, total_design_phase_effort]
  end
  
  def get_analysis_effort(issue)
    analysis_keys = [t(:Analysis_Effort),t(:QA_Analysis_Effort)]
    get_sum(analysis_keys, issue)
  end

  def get_sum(arr,issue)
    arr.each do |ele|
      issue["fields"]["customfield_#{ele}"] = 0 if issue["fields"]["customfield_#{ele}"].nil?
    end

    sum = 0
    arr.each do |ele|
      sum += issue["fields"]["customfield_#{ele}"]
    end
    sum
  end


  def work_request_delivery_cycle_time(total_work_requests_committed)
    @work_req_delayed = []
    @work_req_on_time = []
    @work_req_not_delivered = []
    complexity = []
    @complexity_requests_hash = Hash.new
    @total_review_effort = 0
    total_work_requests_committed.each do |issue|
      if issue['fields']['resolutiondate']
        resol_date = Time.parse(issue['fields']['resolutiondate'])
        due_date = Time.parse(issue['fields']['duedate'])
        issuetype = issue['fields']['issuetype']['name']
        issue_complexity = issue['fields']["customfield_#{t(:complexity)}"].present? ? issue['fields']["customfield_#{t(:complexity)}"]['value'] : 'Low'
        complexity << issue_complexity
        @complexity_requests_hash[issue_complexity] = @complexity_requests_hash[issue_complexity].blank? ? [issuetype] : @complexity_requests_hash[issue_complexity] + [issuetype]
        @total_review_effort += get_total_review_effort(issue)
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
  end

  def get_development_effectiveness_defects(project, from_date, to_date)
    response = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND type IN \\u0028Review\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u002CDelivered\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u002CTesting\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029\\u0029 AND duedate IS NOT EMPTY"}}')
    parsed_response=JSON.parse(response)
    total_work_req_delivered = []
    complexity = []
    @complexity_defects_hash = Hash.new
    parsed_response['issues'].each do |issue|
      if issue['fields']['resolutiondate']
        resol_date = Time.parse(issue['fields']['resolutiondate'])
        due_date = Time.parse(issue['fields']['duedate'])
        issuetype = issue['fields']['issuetype']['name']
        issue_complexity = issue['fields']["customfield_#{t(:complexity)}"].present? ? issue['fields']["customfield_#{t(:complexity)}"]['value'] : 'Low'
        complexity << issue_complexity
        @complexity_defects_hash[issue_complexity] = @complexity_defects_hash[issue_complexity].blank? ? [issuetype] : @complexity_defects_hash[issue_complexity] + [issuetype]
        if resol_date > due_date || resol_date <= due_date
          total_work_req_delivered << issue
        end
      end
    end
    defects = total_work_req_delivered.map{|ele| ele['fields']['issuetype']['name']}
    @defect_counts = Hash.new(0)
    defects.each { |name| @defect_counts[name] += 1 }
    @review_defects = total_work_req_delivered.select do |ele|
      ele['fields']['issuetype']['name'] == "Review Defect (NWF)"
    end
    @delivered_defects = total_work_req_delivered.select do |ele|
      ele['fields']['issuetype']['name'] == "Delivered Defect (NWF)"
    end
    @testing_defects = total_work_req_delivered.select do |ele|
      ele['fields']['issuetype']['name'] == "Testing Defect (NWF)"
    end
    @inprocess_defects = @review_defects + @testing_defects
    
    # @total_review_effort in seconds
    @total_review_effort = ((@review_defects.map{|ele| ele['fields']['timespent']}.sum).to_f/3600.to_f).round(2)

    #Defect Data Distribution table: eg:{"Low"=>["Delivered Defect", "Testing Defect", "Delivered Defect", "Review Defect"]}
  end

  #returns sum of analysis review, design review, code review, testing review for qa, testing review for unittesting reviews
  def get_total_review_effort(issue)
    issue['fields']['customfield_10029'].to_f + issue['fields']['customfield_10034'].to_f + issue['fields']['customfield_10038'].to_f + issue['fields']['customfield_10105'].to_f + issue['fields']['customfield_10106'].to_f
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
      cycle_time = all_complex_issues[key].map{|ele| get_cycle_time(ele["fields"]["resolutiondate"], ele["fields"]["customfield_#{t(:Task_Started_Date)}"], ele["fields"]["customfield_#{t(:Hold_Time)}"])}
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

  def get_cycle_time(resolution_date, start_date, hold_time)
    # hold_time_in_seconds =  hold_time.nil? ? 0 : hold_time*24*60*60
    # Time.parse(resolution_date) - Time.parse(start_date) - hold_time_in_seconds
    return 0 if start_date.nil?
    hold_time_in_seconds =  hold_time.nil? ? 0 : hold_time*24*60*60
    resolutiondate = resolution_date.nil? ? 0 : Time.parse(resolution_date)
    startdate = start_date.nil? ? 0 : Time.parse(start_date)
    resolutiondate - startdate - hold_time_in_seconds
  end

  #returns hash
  def get_all_complex_issues(total_work_requests_delivered)
    all_complex_issues = {}
    total_work_requests_delivered.each do |issue|
      if issue['fields']["customfield_#{t(:complexity)}"].present?
        all_complex_issues[issue['fields']["customfield_#{t(:complexity)}"]['value']] = all_complex_issues[issue['fields']["customfield_#{t(:complexity)}"]['value']].blank? ? [issue] : all_complex_issues[issue['fields']["customfield_#{t(:complexity)}"]['value']] + [issue]
      end
    end
    all_complex_issues
  end

  def get_development_effectiveness(total_work_requests_delivered, project)
    issue_parent_ids = []
    total_work_requests_delivered.map{|issue| issue_parent_ids << issue['key'] }
    parent_ids = issue_parent_ids.map { |i| "'" + i.to_s + "'" }.join(",")
    testing_sub_tasks =  get_testing_tasks(parent_ids, project)
    testing_sub_tasks = JSON.parse(testing_sub_tasks)
    build_development_effectiveness_hash(testing_sub_tasks)

    testing_defects = get_testing_defects(parent_ids,project)
    testing_defects = JSON.parse(testing_defects)
    build_testing_defect_hash(testing_defects)
  end

  def get_sub_tasks(from_date, to_date, parent_key, project)
    sub_tasks = post_search('search','{"jql":"project='"#{project}"' AND created>='"#{from_date}"' AND created<='"#{to_date}"' AND duedate IS NOT EMPTY AND parent = '"#{parent_key}"'","fields":["id","key","duedate","resolutiondate","issuetype","customfield_11352","timespent"]}}')
    sub_tasks = JSON.parse(sub_tasks)
    sub_tasks['issues']
  end

  def get_testing_tasks(issue_parent_ids,project)
    if issue_parent_ids.length > 0 
      testing_tasks = post_search('search', '{"jql":"project='"#{project}"' AND type = Testing\\\u0020Task\\\u0020\\\u0028NWF\\\u0029 AND parent in \\u0028'"#{issue_parent_ids}"'\\u0029"}')
    end
  end

  def get_testing_defects(issue_parent_ids,project)
    if issue_parent_ids.length > 0 
      testing_tasks = post_search('search', '{"jql":"project='"#{project}"' AND type = Testing\\\u0020Defect\\\u0020\\\u0028NWF\\\u0029 AND parent in \\u0028'"#{issue_parent_ids}"'\\u0029"}')
    end
  end

  def build_development_effectiveness_hash(testing_tasks)
    planned_count = 0
    testing_tasks['issues'].map{|issue| planned_count += issue['fields']["customfield_#{t(:TestDesignPlanned)}"].to_i }
    $development_effectiveness['Test Design Planned'] = planned_count
    #Test Design Developed
    tdd = 0 
    testing_tasks['issues'].map{|issue| tdd += issue['fields']["customfield_#{t(:TestDesignDeveloped)}"].to_i }
    $development_effectiveness['Test Design Developed'] = tdd
    #Test Cases Planned for Execution
    pte = 0 
    testing_tasks['issues'].map{|issue| pte += issue['fields']["customfield_#{t(:TestCasesPlannedForExecution)}"].to_i }
    $development_effectiveness['Test Cases Planned for Execution'] = pte
    #Test Cases Actually Executed
    tae = 0
    testing_tasks['issues'].map{|issue| tae += issue['fields']["customfield_#{t(:TestCasesActuallyExecuted)}"].to_i }
    $development_effectiveness['Test Cases Actually Executed'] = tae
  end

  def build_testing_defect_hash(testing_defects)
   puts "testing_defects =======> #{testing_defects.length.inspect}"
   $development_effectiveness['Defects in Test Design'] = testing_defects.length
  end
  
  def build_hash
    $development_effectiveness = {"Test Design Planned" => 0,"Test Design Developed" => 0,"Defects in Test Design" => 0,
                                "Test Cases Planned for Execution" => 0,"Test Cases Actually Executed" => 0,"Test Execution (%)" => 0,
                                "Test Coverage (%)" => 0}
  end                                
end
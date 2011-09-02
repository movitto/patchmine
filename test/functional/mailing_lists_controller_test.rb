require File.dirname(__FILE__) + '/../test_helper'

class MailingListsControllerTest < ActionController::TestCase
  fixtures :mailing_lists, :projects, :users

  def setup
    @project = Project.find(1)
    @project.enabled_module_names = [:blogroll]

    @list = mailing_lists(:mailing_list_001)

    @request.session[:user_id] = 2
    Role.find(1).add_permission! :view_blogroll
    Role.find(1).add_permission! :manage_blogroll
    User.current = User.find(2)
  end

  def test_routing
    assert_routing({:method => :get, :path => '/mailing_lists'},
                    :controller => 'mailing_lists', :action => 'index')
    assert_routing({:method => :post, :path => '/mailing_lists/create'},
                    :controller => 'mailing_lists', :action => 'create')
    assert_routing({:method => :post, :path => '/mailing_lists/delete'},
                    :controller => 'mailing_lists', :action => 'delete')
  end

  def test_index
    get :index, :project_id => @project.identifier
    assert_response :success
    assert_not_nil assigns(:project)
    assert_not_nil assigns(:mailing_lists)
  end

  def test_create
    c = MailingList.count
    post :create, :project_id => @project.identifier, :address => 'foo@bar.com'
    assert  MailingList.count == (c+1)
    assert !MailingList.find(:first, 
                             :conditions => ['address = ? AND project_id', 
                                             'foo@bar.com', @project.id]).nil?

    assert_response :redirect
    assert_redirected_to "/mailing_lists?project_id=#{@project.identifier}"
  end

  def test_delete
    post :create, :project_id => @project.identifier, :address => 'foo@bar.com'

    c = MailingList.count
    ml = MailingList.find(:first, :conditions => ['address = ?', 'foo@bar.com'])

    post :delete, {:id => ml.id}
                        
    assert_response :redirect
    assert_redirected_to "/mailing_lists?project_id=#{@project.identifier}"

    assert MailingList.count == (c-1)
    assert MailingList.find(:first, :conditions => ['url = ?',  'test_delete_blog']).nil?
  end
end

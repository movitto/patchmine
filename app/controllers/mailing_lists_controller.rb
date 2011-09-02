class MailingListsController < ApplicationController
  unloadable

  before_filter :find_project, :authorize

  def index
    @mailing_lists = MailingList.find(:all, :conditions => {:project_id => @project.id})
    @mailing_lists.each { |ml| ml.sync } # FIXME invoke ml.sync asyncronously periodically
    @mailing_list = MailingList.new
  end

  def create
    @mailing_list = MailingList.create(params[:mailing_list])
    @mailing_list.subscribe
    redirect_to :action => :index, :project_id => @project.id
  end

  def delete
    MailingList.delete(params[:id])
    redirect_to :action => :index, :project_id => @project.id
  end

  private
  def find_project
    @project = Project.find(params[:project_id])
  end
end

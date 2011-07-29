class MailingListsController < ApplicationController
  unloadable

  def index
    @mailing_lists = MailingList.find(:all)
    @mailing_lists.each { |ml| ml.update } # FIXME invoke ml.update asyncronously periodically
  end

  def new
    @mailing_list = MailingList.new
  end

  def create
    @mailing_list = MailingList.create(params[:mailing_list])
    @mailing_list.subscribe
    redirect_to :action => :index
  end

  def edit
    @mailing_list = MailingList.find(params[:id])
  end

  def update
    @mailing_list = MailingList.find(params[:id])
    @mailing_list.update_attributes!(params[:mailing_list])
    #@mailing_list.subscribe
    redirect_to :action => :index
  end

  def delete
    MailingList.delete(params[:id])
    redirect_to :action => :index
  end
end

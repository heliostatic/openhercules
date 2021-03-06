class ListsController < ApplicationController
  before_filter :authenticate_user!, :except => [:show, :clone]
   
  def index
    if current_user.lists.empty?
      List.create_first(current_user)
    end
    redirect_to current_user.last_viewed_list || current_user.lists.first
  end
  
  def show    
    begin
      @list = List.find(params[:id])
    rescue Mongoid::Errors::DocumentNotFound
      @list = nil
    end

    @list = nil unless can?(:read, @list)
    current_user.update_attribute(:last_viewed_list_id, @list.id) if @list && @list.user == current_user
    @lists = current_user.lists_organized_instantiated if user_signed_in?
  end
    
  def create
    list = current_user.lists.create(name: params[:name], description: params[:description])
    redirect_to(list)
  end
  
  def update
    @list = List.find(params[:id])
    if can?(:modify_items, @list)
      # ensure that read-write user doesn't try to modify something
      # other than items
      if can?(:modify_properties, @list)
        list_params = params[:list]
      else
        list_params = {items: params[:list][:items]}
      end
      
      @list.update_attributes(list_params)
      @list.save
      render :status => 200, :text => "success"
    else
      render :status => 401, :text => "insufficient permissions"
    end
  end

  def destroy
    @list = current_user.lists.find(params[:id])
    @list.destroy
    redirect_to lists_path
  end

  def clone
    create_anonymous_user
    @list = List.find(params[:id])
    new_list = @list.clone(current_user, params[:name], params[:description])
    redirect_to(new_list)
  end
end

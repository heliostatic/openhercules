class User
  include Mongoid::Document
  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
         
  field :anonymous,           type: Boolean
  field :username,            type: String
  field :email,               type: String
  field :last_viewed_list_id, type: Integer
  field :lists_organized,     type: Array,  default: []
  field :preferences,         type: Hash, default: {
    "show-commands" => false
  }

  index :username, unique: true
  index :email, unique: true
  
  has_many :lists
  
  validates_presence_of   :username, :if => :username_required?
  validates_uniqueness_of :username, :allow_blank => true
  validates_length_of     :username, :within => 4..24, :allow_blank => true
    
  scope :username_like, ->(username) { where("username" => /^#{username}/) }

  PreferenceNames = %w{show-commands}
  
  class << self
    def create_anonymous_user
      create(anonymous: true, remember_me: true, password: "anonymous", password_confirmation: "anonymous")
    end

    def user_and_id(user_or_id)
      if user_or_id.respond_to?(:id)
        [user_or_id.id.to_s, user_or_id]
      else
        [user_or_id, find(user_or_id)]
      end
    end
  end
  
  def email_required?
    !anonymous
  end
  
  def password_required?
    !anonymous && super
  end
  
  def username_required?
    !anonymous
  end

  def as_json(options = {})
    {
      id: id,
      lists_organized: lists_organized,
      preferences: preferences
    }
  end
  
  def last_viewed_list
    begin
      List.find(last_viewed_list_id) if last_viewed_list_id
    rescue Mongoid::Errors::DocumentNotFound
      nil
    end
  end

  def lists_organized_instantiated
    @lists_organized_instantiated ||= lists_organized.collect{|l| List.find(l["list_id"])}
  end
      
  def receive_list(list)
    list_info = {
      "list_id" => list.id.to_s
    }
    
    if !has_received_list?(list)
      add_list_invitation(list_info)
    end
    save
  end
  
  def add_list_invitation(list_info)
    self.lists_organized << list_info
  end  
  
  def has_received_list?(list)
    self.lists_organized.collect{|i| i["list_id"]}.include? list.id.to_s
  end

  def remove_list(list)
    self.lists_organized = self.lists_organized.reject{ |l| l["list_id"] == list.id.to_s }
    save
  end
  
  def permission_for(list)
    return ListPermissions::OWNER if list.user == self
    
    list_permission_index = if list.readers.include? self.id.to_s
      1
    elsif list.writers.include? self.id.to_s
      2
    elsif list.user = self
      3
    else
      0
    end

    global_permission_index = ListPermissions.ordered.index(list.global_permission)
    
    if global_permission_index > list_permission_index
      ListPermissions.ordered[global_permission_index]
    else
      ListPermissions.ordered[list_permission_index]
    end                         
  end
    
end

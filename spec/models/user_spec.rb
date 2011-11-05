require 'spec_helper'

describe User do

  let(:user) { FactoryGirl.create(:user) }
  let(:user2) { FactoryGirl.create(:user) }
  
  describe ".like" do
    it "should only return users where the username starts with the given text" do
      u1 = FactoryGirl.create(:user, :username => "george")
      u2 = FactoryGirl.create(:user, :username => "benny")
      
      User.username_like("geo").should == [u1]
      User.username_like("ben").should == [u2]
    end
  end

  describe "#receive_list" do
    it "should add a list to list invitations if the user doesn't already have the list" do
      list = List.create_default(user)
      user2.receive_list(list, User::LIST_PERMISSIONS[0])
      
      user2.list_invitations.should == [{
        list_id: list.id.to_s,
        permission: User::LIST_PERMISSIONS[0]
      }]
    end
    
    it "should update list permissions if the user already has the list" do
      list = List.create_default(user)
      user2.receive_list(list, User::LIST_PERMISSIONS[0])
      user2.receive_list(list, User::LIST_PERMISSIONS[1])
      
      user2.list_invitations.should == [{
        list_id: list.id.to_s,
        permission: User::LIST_PERMISSIONS[1]
      }]
    end
  end

end

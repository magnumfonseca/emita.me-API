# frozen_string_literal: true

class AddGovBrAccessTokenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :gov_br_access_token, :string
  end
end

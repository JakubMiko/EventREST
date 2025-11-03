class ChangeStatusInOrders < ActiveRecord::Migration[8.0]
  def change
    change_column :orders, :status, :string, null: false, default: "pending"
  end
end

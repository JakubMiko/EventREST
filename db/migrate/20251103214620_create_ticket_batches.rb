class CreateTicketBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_batches do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :available_tickets
      t.decimal :price
      t.datetime :sale_start
      t.datetime :sale_end

      t.timestamps
    end
  end
end

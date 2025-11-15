class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
      add_index :events, :date

      add_index :events, :category

      add_index :events, [ :date, :category ]

      add_index :orders, :status
      add_index :ticket_batches, :sale_start
      add_index :ticket_batches, :sale_end
    end
end

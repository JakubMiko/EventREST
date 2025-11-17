  # frozen_string_literal: true

  require 'faker'

  # ============================================
  # DETERMINISTIC SEED CONFIGURATION
  # ============================================
  # These seed values ensure IDENTICAL data on every run
  # Critical for fair benchmark comparisons between GraphQL and REST APIs

  # Seed Ruby's Random for deterministic rand(), sample, shuffle, etc.
  Random.srand(42)

  # Seed Faker for deterministic fake names, descriptions, dates, etc.
  Faker::Config.random = Random.new(42)

  puts "\n" + "="*70
  puts "BENCHMARK SEED DATA GENERATOR".center(70)
  puts "="*70
  puts "Environment: #{Rails.env}"
  puts "Mode: DETERMINISTIC (identical data every run)"
  start_time = Time.current

  # ============================================
  # CONFIGURATION - Targeting ~450MB database
  # ============================================
  ADMIN_COUNT = 20
  REGULAR_USERS_COUNT = 9_980
  TOTAL_USERS = 10_000

  TOTAL_EVENTS = 15_000
  PAST_EVENTS_COUNT = 10_000    # 2/3 are past events
  FUTURE_EVENTS_COUNT = 5_000   # 1/3 are upcoming

  AVG_TICKET_BATCHES_PER_EVENT = 6  # early bird, regular, VIP, group, student, late

  # Order probability (past events have more orders)
  PAST_EVENT_ORDER_PROBABILITY = 0.70    # 70% of past event batches sold
  FUTURE_EVENT_ORDER_PROBABILITY = 0.25  # 25% of future batches sold

  # Orders per batch that gets ordered
  ORDERS_PER_SOLD_BATCH = 2..4  # 2-4 different users buy from same batch

  # ============================================
  # CLEAN DATABASE
  # ============================================
  if Rails.env.development? || (Rails.env.production? && ENV['FORCE_SEED'] == 'true')
    puts "\n🗑️  Cleaning database..."

    Ticket.delete_all
    Order.delete_all
    TicketBatch.delete_all
    Event.delete_all
    User.delete_all

    # Reset auto-increment sequences
    %w[users events ticket_batches orders tickets].each do |table|
      ActiveRecord::Base.connection.reset_pk_sequence!(table)
    end

    puts "✓ Database cleaned"
  else
    puts "\n⚠️  Skipping database clean (set FORCE_SEED=true to enable)"
  end

  # ============================================
  # HELPER: Format numbers with commas
  # ============================================
  def format_number(num)
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  # ============================================
  # 1. CREATE USERS
  # ============================================
  puts "\n👥 Creating #{format_number(TOTAL_USERS+1)} users..."
  users_data = []

  # Create test user for benchmarking (no related records)
  puts "Creating test user for benchmarks..."
  User.find_or_create_by!(email: 'test@benchmark.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
    user.first_name = 'Test'
    user.last_name = 'User'
    user.admin = true
  end
  puts "✓ Test user created"

  # OPTIMIZATION: Encrypt password once and reuse for all seed users
  # This saves ~8 minutes of BCrypt encryption time!
  puts "  Generating encrypted password..."
  encrypted_password_for_seed = User.new(password: "password").encrypted_password

  # Create 20 admin users
  ADMIN_COUNT.times do |i|
    users_data << {
      email: "admin#{i + 1}@benchmark.test",
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      encrypted_password: encrypted_password_for_seed,
      admin: true,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  # Create regular users
  puts "  Building user data..."
  batch_size = 2000
  batches_count = (REGULAR_USERS_COUNT / batch_size.to_f).ceil

  batches_count.times do |batch_num|
    current_batch_size = [ batch_size, REGULAR_USERS_COUNT - (batch_num * batch_size) ].min

    current_batch_size.times do |i|
      user_num = (batch_num * batch_size) + i + 1
      users_data << {
        email: "user#{user_num}@benchmark.test",
        first_name: Faker::Name.first_name,
        last_name: Faker::Name.last_name,
        encrypted_password: encrypted_password_for_seed,
        admin: false,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    progress = ((batch_num + 1) * 100.0 / batches_count).round(1)
    puts "    Progress: #{progress}%"
  end

  # Insert all users in chunks
  puts "  Inserting users into database..."
  users_data.each_slice(5000) do |chunk|
    User.insert_all!(chunk)
  end

  all_users = User.all.to_a
  admin_count = User.where(admin: true).count
  puts "✓ Created #{format_number(all_users.count)} users (#{admin_count} admins)"

  # ============================================
  # 2. CREATE EVENTS
  # ============================================
  puts "\n🎭 Creating #{format_number(TOTAL_EVENTS)} events..."

  categories = [ 'music', 'conference', 'festival', 'sports', 'theater', 'workshop', 'art', 'tech', 'food', 'wellness' ]
  places = [
    'Warsaw Arena', 'Warsaw National Stadium', 'Warsaw Expo Center',
    'Krakow Arena', 'Krakow Expo', 'Krakow Main Square',
    'Gdansk Stadium', 'Gdansk Convention Center', 'Gdansk Beach Stage',
    'Wroclaw Hall', 'Wroclaw Arena', 'Wroclaw Market Square',
    'Poznan Stadium', 'Poznan Expo', 'Poznan Old Market',
    'Lodz Theater', 'Lodz Concert Hall', 'Lodz Philharmonic',
    'Katowice Hub', 'Katowice Spodek', 'Katowice Conference Center',
    'Szczecin Hall', 'Szczecin Stadium', 'Szczecin Philharmonic'
  ]

  event_types = [
    'Festival', 'Concert', 'Summit', 'Expo', 'Conference',
    'Championship', 'Tournament', 'Workshop', 'Meetup',
    'Gala', 'Show', 'Exhibition', 'Symposium', 'Forum',
    'Convention', 'Showcase', 'Premiere', 'Launch'
  ]

  genres = [
    'Rock', 'Jazz', 'Classical', 'Electronic', 'Hip Hop',
    'Pop', 'Metal', 'Indie', 'Folk', 'Blues', 'Techno',
    'House', 'Trance', 'Ambient', 'Punk', 'Country'
  ]

  events_data = []

  # Create PAST events (10,000)
  puts "  Creating #{format_number(PAST_EVENTS_COUNT)} past events..."
  past_batch_size = 1000
  past_batches = (PAST_EVENTS_COUNT / past_batch_size.to_f).ceil

  past_batches.times do |batch|
    past_batch_size.times do |i|
      break if (batch * past_batch_size + i) >= PAST_EVENTS_COUNT

      event_num = (batch * past_batch_size) + i + 1

      # Events from 3 years ago to yesterday
      date = Faker::Time.between(from: 3.years.ago, to: 1.day.ago)

      # Vary description length (1-6 sentences) for realistic data size
      description_sentences = rand(1..6)

      events_data << {
        name: "#{genres.sample} #{event_types.sample} #{event_num}",
        description: Faker::Lorem.paragraph(sentence_count: description_sentences),
        place: places.sample,
        date: date,
        category: categories.sample,
        created_at: date - rand(1..6).months,
        updated_at: date - rand(1..6).months
      }
    end

    if (batch + 1) % 2 == 0  # Every 2000 events
      progress = ((batch + 1) * past_batch_size * 100.0 / PAST_EVENTS_COUNT).round(1)
      puts "    Progress: #{progress}%"
    end
  end

  # Create FUTURE events (5,000)
  puts "  Creating #{format_number(FUTURE_EVENTS_COUNT)} future events..."
  future_batch_size = 1000
  future_batches = (FUTURE_EVENTS_COUNT / future_batch_size.to_f).ceil

  future_batches.times do |batch|
    future_batch_size.times do |i|
      break if (batch * future_batch_size + i) >= FUTURE_EVENTS_COUNT

      event_num = PAST_EVENTS_COUNT + (batch * future_batch_size) + i + 1

      # Events from tomorrow to 2 years from now
      date = Faker::Time.between(from: 1.day.from_now, to: 2.years.from_now)

      description_sentences = rand(1..6)

      events_data << {
        name: "#{genres.sample} #{event_types.sample} #{event_num}",
        description: Faker::Lorem.paragraph(sentence_count: description_sentences),
        place: places.sample,
        date: date,
        category: categories.sample,
        created_at: Time.current - rand(0..90).days,
        updated_at: Time.current - rand(0..30).days
      }
    end

    if (batch + 1) % 1 == 0  # Every 1000 events
      total_created = PAST_EVENTS_COUNT + ((batch + 1) * future_batch_size)
      progress = (total_created * 100.0 / TOTAL_EVENTS).round(1)
      puts "    Progress: #{progress}%"
    end
  end

  # Insert events in chunks
  puts "  Inserting events into database..."
  events_data.each_slice(5000) do |chunk|
    Event.insert_all!(chunk)
  end

  all_events = Event.all.to_a
  past_events = all_events.select { |e| e.date < Time.current }
  future_events = all_events.select { |e| e.date >= Time.current }

  puts "✓ Created #{format_number(all_events.count)} events"
  puts "  → #{format_number(past_events.count)} past events"
  puts "  → #{format_number(future_events.count)} future events"

  # ============================================
  # 3. CREATE TICKET BATCHES
  # ============================================
  puts "\n🎫 Creating ticket batches (#{AVG_TICKET_BATCHES_PER_EVENT} per event)..."
  ticket_batches_data = []

  batch_types = [
    { name: 'Early Bird', days_before: 90, duration: 30, price_multiplier: 0.7 },
    { name: 'Regular', days_before: 60, duration: 45, price_multiplier: 1.0 },
    { name: 'VIP', days_before: 60, duration: 55, price_multiplier: 2.5 },
    { name: 'Group', days_before: 45, duration: 40, price_multiplier: 0.85 },
    { name: 'Student', days_before: 30, duration: 25, price_multiplier: 0.6 },
    { name: 'Last Minute', days_before: 7, duration: 6, price_multiplier: 1.2 }
  ]

  all_events.each_with_index do |event, idx|
    base_price = rand(30..200)

    # Use all 6 batch types
    batch_types.each do |batch_type|
      sale_start = event.date - batch_type[:days_before].days
      sale_end = sale_start + batch_type[:duration].days

      # Don't create batches that would end after the event
      next if sale_end > event.date

      ticket_batches_data << {
        event_id: event.id,
        sale_start: sale_start,
        sale_end: sale_end,
        available_tickets: rand(50..800),
        price: (base_price * batch_type[:price_multiplier]).round(2),
        created_at: event.created_at,
        updated_at: event.created_at
      }
    end

    # Progress update every 1500 events
    if (idx + 1) % 1500 == 0
      progress = ((idx + 1) * 100.0 / all_events.count).round(1)
      puts "    Progress: #{progress}%"
    end
  end

  # Insert in chunks
  puts "  Inserting ticket batches into database..."
  ticket_batches_data.each_slice(10000) do |chunk|
    TicketBatch.insert_all!(chunk)
  end

  all_ticket_batches = TicketBatch.all.to_a
  puts "✓ Created #{format_number(all_ticket_batches.count)} ticket batches"

  # ============================================
  # 4. CREATE ORDERS
  # ============================================
  puts "\n💳 Creating orders..."
  puts "  Strategy: Past events #{(PAST_EVENT_ORDER_PROBABILITY * 100).round}% sold, Future events #{(FUTURE_EVENT_ORDER_PROBABILITY * 100).round}% sold"

  orders_data = []

  # Separate batches by event type
  past_event_ids = past_events.map(&:id).to_set
  future_event_ids = future_events.map(&:id).to_set

  past_batches = all_ticket_batches.select { |tb| past_event_ids.include?(tb.event_id) }
  future_batches = all_ticket_batches.select { |tb| future_event_ids.include?(tb.event_id) }

  # Process PAST event batches
  puts "  Processing #{format_number(past_batches.count)} past event batches..."
  past_batches.each_with_index do |tb, idx|
    next if rand > PAST_EVENT_ORDER_PROBABILITY

    # Create 2-4 orders per sold batch
    rand(ORDERS_PER_SOLD_BATCH).times do
      user = all_users.sample
      quantity = rand(1..8)
      total_price = tb.price * quantity
      order_date = tb.sale_start + rand(0..(tb.sale_end - tb.sale_start).to_i).seconds

      orders_data << {
        user_id: user.id,
        ticket_batch_id: tb.id,
        quantity: quantity,
        total_price: total_price,
        status: 'paid',  # All past orders are paid
        created_at: order_date,
        updated_at: order_date
      }
    end

    if (idx + 1) % 10000 == 0
      progress = ((idx + 1) * 100.0 / past_batches.count).round(1)
      puts "    Progress: #{progress}%"
    end
  end

  # Process FUTURE event batches
  puts "  Processing #{format_number(future_batches.count)} future event batches..."
  future_batches.each_with_index do |tb, idx|
    next if rand > FUTURE_EVENT_ORDER_PROBABILITY

    # Create 1-3 orders per sold batch
    rand(1..3).times do
      user = all_users.sample
      quantity = rand(1..5)
      total_price = tb.price * quantity

      orders_data << {
        user_id: user.id,
        ticket_batch_id: tb.id,
        quantity: quantity,
        total_price: total_price,
        status: [ 'pending', 'paid', 'paid', 'paid', 'paid' ].sample,  # 80% paid
        created_at: Time.current - rand(1..60).days,
        updated_at: Time.current - rand(0..30).days
      }
    end

    if (idx + 1) % 5000 == 0
      progress = ((idx + 1) * 100.0 / future_batches.count).round(1)
      puts "    Progress: #{progress}%"
    end
  end

  # Insert orders in chunks
  puts "  Inserting #{format_number(orders_data.count)} orders into database..."
  orders_data.each_slice(10000) do |chunk|
    Order.insert_all!(chunk)
  end

  all_orders = Order.all.to_a
  paid_orders_count = Order.where(status: 'paid').count
  puts "✓ Created #{format_number(all_orders.count)} orders (#{format_number(paid_orders_count)} paid)"

  # ============================================
  # 5. CREATE TICKETS
  # ============================================
  puts "\n🎟️  Creating tickets for orders..."
  tickets_data = []

  all_orders.each_with_index do |order, idx|
    order.quantity.times do
      tickets_data << {
        order_id: order.id,
        user_id: order.user_id,
        event_id: order.ticket_batch.event_id,
        price: order.ticket_batch.price,
        ticket_number: SecureRandom.hex(8),
        created_at: order.created_at,
        updated_at: order.created_at
      }
    end

    if (idx + 1) % 10000 == 0
      progress = ((idx + 1) * 100.0 / all_orders.count).round(1)
      puts "    Progress: #{progress}%"
    end
  end

  # Insert tickets in chunks
  puts "  Inserting #{format_number(tickets_data.count)} tickets into database..."
  tickets_data.each_slice(10000) do |chunk|
    Ticket.insert_all!(chunk)
  end

  total_tickets = Ticket.count
  puts "✓ Created #{format_number(total_tickets)} tickets"

  # ============================================
  # CALCULATE DATABASE SIZE
  # ============================================
  users_size = User.count * 0.5
  events_size = Event.count * 1.2  # Larger due to descriptions
  batches_size = TicketBatch.count * 0.3
  orders_size = Order.count * 0.4
  tickets_size = Ticket.count * 0.3
  raw_size = users_size + events_size + batches_size + orders_size + tickets_size
  estimated_size = raw_size * 3  # Account for indexes

  # ============================================
  # SUMMARY
  # ============================================
  elapsed = (Time.current - start_time).round(2)

  puts "\n" + "="*70
  puts "SEED SUMMARY".center(70)
  puts "="*70
  printf "%-25s %15s   %s\n", "Users:", format_number(User.count), "(#{User.where(admin: true).count} admins)"
  printf "%-25s %15s   %s\n", "Events:", format_number(Event.count), "(#{format_number(past_events.count)} past, #{format_number(future_events.count)} future)"
  printf "%-25s %15s\n", "Ticket Batches:", format_number(TicketBatch.count)
  printf "%-25s %15s   %s\n", "Orders:", format_number(Order.count), "(#{format_number(paid_orders_count)} paid)"
  printf "%-25s %15s\n", "Tickets:", format_number(Ticket.count)
  puts "-"*70
  printf "%-25s %15s\n", "Raw data size:", "~#{(raw_size / 1024).round} MB"
  printf "%-25s %15s\n", "Estimated DB size:", "~#{(estimated_size / 1024).round} MB (with indexes)"
  printf "%-25s %15s\n", "PostgreSQL usage:", "~#{((estimated_size / 1024) / 1024 * 100).round}%"
  printf "%-25s %15s\n", "Seeding time:", "#{elapsed} seconds"
  puts "="*70
  puts "\n✅ Seeding complete! 🎉\n\n"
  puts "Test credentials:"
  puts "  Admin:   admin1@benchmark.test / password"
  puts "  Admin:   admin2@benchmark.test / password"
  puts "  ...      (up to admin20@benchmark.test)"
  puts ""
  puts "  User:    user1@benchmark.test / password"
  puts "  User:    user2@benchmark.test / password"
  puts "  ...      (up to user9980@benchmark.test)"
  puts "\n" + "="*70
  puts ""

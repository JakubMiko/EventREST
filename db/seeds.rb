# frozen_string_literal: true

require 'open-uri'

I18n.locale = :en
I18n.default_locale = :en

# Uncomment the following line if you want to clean the database before seeding
# Ticket.delete_all
# Order.delete_all
# TicketBatch.delete_all
# Event.delete_all
# User.delete_all

admin = User.find_or_create_by!(email: "admin@gmail.com") do |u|
  u.first_name = "Admin"
  u.last_name  = "User"
  u.password   = "password"
  u.admin      = true
end

regular_user = User.find_or_create_by!(email: "regular@gmail.com") do |u|
  u.first_name = "Regular"
  u.last_name  = "User"
  u.password   = "password"
  u.admin      = false
end

events_data = [
  {
    name: "Neon Nights Festival",
    place: "Warsaw Arena",
    date: Time.zone.parse("2025-11-08 19:00"),
    ends_at:   Time.zone.parse("2025-11-08 23:59"),
    description: "Immersive light show, synthwave and visual arts. One night, thousands of lights.",
    category: "music"
  },
  {
    name: "Jazz by the River",
    place: "Krakow – Vistula Boulevards",
    date: Time.zone.parse("2025-09-27 18:30"),
    ends_at:   Time.zone.parse("2025-09-27 22:30"),
    description: "Open-air concert with top jazz artists right next to the river.",
    category: "music"
  },
  {
    name: "Tech Future Summit",
    place: "Gdansk Expo",
    date: Time.zone.parse("2026-03-14 09:00"),
    ends_at:   Time.zone.parse("2026-03-14 18:00"),
    description: "Talks, demos and startups. AI, robotics and cloud in one place.",
    category: "conference"
  },
  {
    name: "Comic Expo",
    place: "Wroclaw Convention Center",
    date: Time.zone.parse("2026-02-07 10:00"),
    ends_at:   Time.zone.parse("2026-02-07 19:00"),
    description: "Comics, cosplay and collectibles. Meet creators and your favorite characters.",
    category: "festival"
  },
  {
    name: "Winter Gala",
    place: "Lodz Philharmonic",
    date: Time.zone.parse("2025-12-20 19:00"),
    ends_at:   Time.zone.parse("2025-12-20 22:00"),
    description: "Elegant evening with classical highlights and solo performances.",
    category: "music"
  },
  {
    name: "Summer Beats Open Air",
    place: "Poznan Lake Stage",
    date: Time.zone.parse("2026-06-21 16:00"),
    ends_at:   Time.zone.parse("2026-06-21 23:30"),
    description: "House and techno on a lakeside stage. Sunset guaranteed.",
    category: "music"
  },
  {
    name: "Startup Pitch Day",
    place: "Katowice Hub",
    date: Time.zone.parse("2026-01-29 10:00"),
    ends_at:   Time.zone.parse("2026-01-29 17:00"),
    description: "Founders pitch to VCs. Networking, mentoring and live feedback.",
    category: "conference"
  },
  {
    name: "Classical Evening",
    place: "Szczecin Philharmonic",
    date: Time.zone.parse("2026-04-05 19:30"),
    ends_at:   Time.zone.parse("2026-04-05 21:30"),
    description: "Romantic era program with a focus on Chopin and Tchaikovsky.",
    category: "music"
  }
]

events_data.each do |attrs|
  allowed = Event.column_names.map(&:to_sym)
  event = Event.find_or_initialize_by(name: attrs[:name])
  event.assign_attributes(attrs.slice(*allowed))
  event.save!

  if event.respond_to?(:image) && !event.image.attached?
    slug = event.name.to_s.parameterize
    path = Rails.root.join("app/assets/images/seed_images/#{slug}.jpg")
    event.image.attach(io: File.open(path), filename: "#{slug}.jpg") if File.exist?(path)
  end
end

puts "Seeded #{Event.count} events."

ticket_batches = []
Event.find_each do |event|
  next unless event.date.present?

  sale_start = event.date - 30.days
  sale_end   = event.date - 1.day

  ticket_batch = event.ticket_batches.find_or_create_by!(
    sale_start: sale_start,
    sale_end:   sale_end
  ) do |tb|
    tb.available_tickets = rand(50..100)
    tb.price             = rand(50..200)
  end

  ticket_batches << ticket_batch
end

orders = []
ticket_batches.each do |ticket_batch|
  order1 = Order.find_or_initialize_by(user: regular_user, ticket_batch: ticket_batch)
  order1.quantity = 2
  order1.status = "paid"
  order1.total_price = ticket_batch.price * order1.quantity
  order1.save!
  orders << order1

  order2 = Order.find_or_initialize_by(user: admin, ticket_batch: ticket_batch)
  order2.quantity = 1
  order2.status = "paid"
  order2.total_price = ticket_batch.price * order2.quantity
  order2.save!
  orders << order2
end

orders.each do |order|
  missing = order.quantity - order.tickets.count
  missing.times do
    Ticket.create!(
      order: order,
      user: order.user,
      event: order.ticket_batch.event,
      price: order.ticket_batch.price,
      ticket_number: SecureRandom.hex(8)
    )
  end
end

puts "Seeds created successfully"

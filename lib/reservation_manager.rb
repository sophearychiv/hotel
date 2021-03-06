require_relative "reservation"
require_relative "room"
require_relative "block"
require_relative "date_range"
require "awesome_print"

module Hotel
  class ReservationManager

    # To access the list of all of the rooms, reservations and blocks in the hotel
    attr_reader :rooms, :reservations, :blocks

    def initialize
      @rooms = Hotel::Room.load_all
      @reservations = []
      @blocks = []
    end

    # I can reserve an available room for a given date range
    def reserve(room_id:, check_in_date:, check_out_date:)
      self.class.validate_id(room_id)
      available_rooms = find_available_rooms(check_in_date: check_in_date, check_out_date: check_out_date)
      available_room_ids = available_rooms.map { |room| room.room_id }

      # I want an exception raised if I try to reserve a room that is unavailable for a given day
      raise ArgumentError, "Room #{room_id} is not available for this date range!" if available_room_ids.include?(room_id) == false
      new_reservation = new_reservation(room_id, check_in_date, check_out_date)
      add_reservation(new_reservation)
    end

    # I can access the list of reservations for a specific date, so that I can track reservations by date
    def list_reservations(date:)
      date = Hotel::DateRange.validate_date(date)
      reservations = self.reservations.select do |reservation|
        date >= reservation.check_in_date && date < reservation.check_out_date
      end
      return reservations
    end

    # I can get the total cost for a given reservation
    def total_cost(reservation_id:)
      reservation = @reservations.find { |current_reservation| current_reservation.reservation_id == reservation_id }
      reservation.total_cost
    end

    # I can view a list of rooms that are not reserved for a given date range
    def find_available_rooms(check_in_date:, check_out_date:)
      date_range = Hotel::DateRange.new(check_in_date, check_out_date)
      overlap_reservations = date_range.overlap_blocks_reservations(@reservations, check_in_date, check_out_date)
      overlap_room_ids_reservations = overlap_reservations.map { |reservation| reservation.room_id }

      # Given a specific date, and that a room is set aside in a hotel block for that specific date, I cannot reserve or create a block for that specific room for that specific date
      overlap_blocks = date_range.overlap_blocks_reservations(@blocks, check_in_date, check_out_date)
      overlap_room_ids_blocks = []
      overlap_blocks.each do |block|
        block.room_ids.each do |i|
          overlap_room_ids_blocks << i
        end
      end

      overlap_room_ids = (overlap_room_ids_blocks + overlap_room_ids_reservations).uniq
      return available_rooms = @rooms.reject do |room|
               overlap_room_ids.include?(room.room_id)
             end
    end

    # I can create a Hotel Block if I give a date range, collection of rooms, and a discounted room rate
    def create_block(room_ids:, check_in_date:, check_out_date:, discount_rate:)
      room_ids.each { |room_id| self.class.validate_id(room_id) }
      available_rooms = find_available_rooms(check_in_date: check_in_date, check_out_date: check_out_date)
      available_room_ids = available_rooms.map { |room| room.room_id }

      # I want an exception raised if I try to create a Hotel Block and at least one of the rooms is unavailable for the given date range
      room_ids.each do |room_id|
        raise ArgumentError, "Room #{room_id} is not available" if available_room_ids.include?(room_id) == false
      end
      new_block = Hotel::Block.new(
        block_id: @blocks.length + 1,
        room_ids: room_ids,
        check_in_date: check_in_date,
        check_out_date: check_out_date,
        discount_rate: discount_rate,
      )
      @blocks << new_block
      store_blocks_in_csv
      return new_block
    end

    # I can check whether a given block has any rooms available
    def check_available_rooms_in_blocks(block_id:)
      self.class.validate_id(block_id)
      block = @blocks.find { |current_block| current_block.block_id == block_id }
      raise ArgumentError, "Block #{block_id} is not found" if block == nil
      return block.check_available_rooms
    end

    # I can reserve a specific room from a hotel block
    def reserve_from_block(room_id:, block_id:)
      self.class.validate_id(room_id)
      self.class.validate_id(block_id)
      block = @blocks.find { |block| block.block_id == block_id }
      block.reserve_room(room_id: room_id)
      check_in_date = block.check_in_date.to_s
      check_out_date = block.check_out_date.to_s
      new_reservation = new_reservation(room_id, check_in_date, check_out_date)

      # I can see a reservation made from a hotel block
      add_reservation(new_reservation)
      store_blocks_in_csv
      return new_reservation
    end

    # Optional Enhancement: Add functionality that allows for setting different rates for different rooms
    def set_room_rate(room_id:, room_rate:)
      room = @rooms.find { |room| room.room_id == room_id }
      room.change_rate(new_rate: room_rate)
      store_room_rates_in_csv
    end

    private

    def new_reservation(room_id, check_in_date, check_out_date)
      Hotel::Reservation.new(
        reservation_id: @reservations.length + 1,
        room_id: room_id,
        check_in_date: check_in_date,
        check_out_date: check_out_date,
      )
    end

    def add_reservation(new_reservation)
      @reservations << new_reservation
      store_reservations_in_csv
    end

    def store_reservations_in_csv
      reservations_csv = CSV.open("support/reservations.csv", "w+", write_headers: true, headers: ["reservation_id", "room_id", "check_in_date", "check_out_date"])
      @reservations.each do |reservation|
        reservation_hash = { "reservation_id" => reservation.reservation_id,
                            "room_id" => reservation.room_id,
                            "check_in_date" => reservation.check_in_date,
                            "check_out_date" => reservation.check_out_date }
        reservations_csv << reservation_hash
      end
    end

    def store_blocks_in_csv
      blocks_csv = CSV.open("support/blocks.csv", "w+", write_headers: true, headers: ["block_id", "rooms_info", "check_in_date", "check_out_date", "discount_rate"])
      @blocks.each do |block|
        block_hash = {
          "block_id" => block.block_id,
          "rooms_info" => block.rooms_info,
          "check_in_date" => block.check_in_date,
          "check_out_date" => block.check_out_date,
          "discount_rate" => block.discount_rate,
        }
        blocks_csv << block_hash
      end
      blocks_csv.close()
    end

    def store_room_rates_in_csv
      rooms_csv = CSV.open("support/rooms.csv", "w+", write_headers: true, headers: ["room_id", "cost"])
      @rooms.each do |room|
        room_hash = {
          "room_id" => room.room_id,
          "cost" => room.cost.to_f,
        }
        rooms_csv << room_hash
      end
      rooms_csv.close()
    end

    def self.validate_id(id)
      if id.nil? || id <= 0 || id.class != Integer
        raise ArgumentError, "ID must be an integer and cannot be blank or less than zero."
      end
    end
  end
end

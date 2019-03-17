require "pry"
require "date"

module Hotel
  class Reservation
    attr_reader :reservation_id, :room, :room_id, :check_in_date, :check_out_date

    def initialize(reservation_id:,
                   room_id:,
                   check_in_date:,
                   check_out_date:)
      @reservation_id = reservation_id
      @room_id = room_id
      @check_in_date = Date.parse(check_in_date)
      @check_out_date = Date.parse(check_out_date)
    end

    # def cost
    #   num_nights = @check_out_date - @check_in_date
    #   return Hotel::Room.new(1).cost * num_nights
    # end

    def self.load_all
      return @reservations || []
    end
  end
end

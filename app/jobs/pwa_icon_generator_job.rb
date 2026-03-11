class PwaIconGeneratorJob < ApplicationJob
  queue_as :default

  def perform(account_id)
    account = Account.find_by(id: account_id)
    return unless account

    PwaIconGeneratorService.new(account).generate!
  end
end

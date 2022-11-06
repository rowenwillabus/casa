class FundRequestsController < ApplicationController
  before_action :verify_casa_case
  # after_action :verify_authorized

  def new
    # authorize @casa_case
    @fund_request = FundRequest.new
  end

  def create
    # authorize @casa_case
    @fund_request = FundRequest.new(parsed_params)
    if @fund_request.save
      FundRequestMailer.send_request(nil, @fund_request).deliver
      redirect_to casa_case_path(@casa_case), notice: "Fund Request was sent for case #{@casa_case.case_number}"
    else
      render :new
    end
  end

  private

  def verify_casa_case
    @casa_case = CasaCase.friendly.find(params[:casa_case_id])
    unless @casa_case.casa_org == current_user.casa_org
      redirect_to root_path
    end
  end

  def parsed_params
    params.permit(
      :submitter_email,
      :youth_name,
      :payment_amount,
      :deadline,
      :request_purpose,
      :payee_name,
      :requested_by_and_relationship,
      :other_funding_source_sought,
      :impact,
      :extra_information
    )
  end
end

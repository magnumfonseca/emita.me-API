# frozen_string_literal: true

module Api
  module V1
    class ContactsController < ApplicationController
      include Authenticatable

      def index
        contacts = current_user.contacts
                               .by_name(params[:name])
                               .by_cpf(params[:cpf])
                               .by_cnpj(params[:cnpj])
                               .page(params[:page])
        render json: {
          success: true,
          data: ContactSerializer.new(contacts).serializable_hash[:data],
          meta: pagination_meta(contacts),
          message: nil
        }
      end

      def show
        contact = current_user.contacts.find_by(id: params[:id])
        return render_not_found unless contact

        render json: { success: true, data: ContactSerializer.new(contact).serializable_hash[:data], message: nil }
      end

      def create
        contact = current_user.contacts.build(contact_params)
        if contact.save
          render json: {
            success: true,
            data: ContactSerializer.new(contact).serializable_hash[:data],
            message: "Contact created successfully"
          }, status: :created
        else
          render_validation_error(contact)
        end
      end

      def update
        contact = current_user.contacts.find_by(id: params[:id])
        return render_not_found unless contact

        if contact.update(contact_params)
          render json: {
            success: true,
            data: ContactSerializer.new(contact).serializable_hash[:data],
            message: "Contact updated successfully"
          }
        else
          render_validation_error(contact)
        end
      end

      def destroy
        current_user.contacts.find_by(id: params[:id])&.destroy
        render json: { success: true, data: nil, message: "Contact deleted successfully" }
      end

      private

      def contact_params
        params.require(:contact).permit(:name, :email, :cpf, :cnpj, :phone)
      end

      def pagination_meta(contacts)
        {
          current_page: contacts.current_page,
          total_pages: contacts.total_pages,
          total_count: contacts.total_count
        }
      end

      def render_not_found
        render json: {
          success: false,
          data: nil,
          error: { code: "NOT_FOUND", message: "Contact not found", details: [] }
        }, status: :not_found
      end

      def render_validation_error(contact)
        render json: {
          success: false,
          data: nil,
          error: {
            code: "VALIDATION_ERROR",
            message: contact.errors.full_messages.first,
            details: contact.errors.full_messages
          }
        }, status: :unprocessable_entity
      end
    end
  end
end

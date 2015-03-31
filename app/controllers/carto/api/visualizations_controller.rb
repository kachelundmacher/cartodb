require_relative 'visualization_presenter'

module Carto

  module Api

    class VisualizationsController < ::Api::ApplicationController

      FILTER_SHARED_YES = 'yes'
      FILTER_SHARED_NO = 'no'
      FILTER_SHARED_ONLY = 'only'

      def index
        types = params.fetch(:types, '').split(',')
        type = params[:type].present? ? params[:type] : default_type(types)
        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 20).to_i
        only_liked = params[:only_liked] == 'true'
        only_shared = params[:only_shared] == 'true'
        exclude_shared = params[:exclude_shared] == 'true'
        order = (params[:order] || 'updated_at').to_sym

        shared = params[:shared]
        case shared
          when FILTER_SHARED_YES
            only_shared = false
            exclude_shared = false
          when FILTER_SHARED_NO
            only_shared = false
            exclude_shared = true
          when FILTER_SHARED_ONLY
            only_shared = true
            exclude_shared = false
        end
        locked = params[:locked]

        vqb = VisualizationQueryBuilder.new
            .with_prefetch_user
            .with_prefetch_table
            .with_prefetch_permission
            .with_prefetch_external_source
            .with_locked(locked)
            .with_type(type)

        if locked == 'true'
          vqb.with_locked(true)
        elsif locked == 'false'
          vqb.with_locked(false)
        end

        if only_liked || only_shared
          if only_liked
            vqb.with_liked_by_user_id(current_user.id)
          end
          if only_shared
            vqb.with_shared_with_user_id(current_user.id)
          end
        else
          if exclude_shared
            vqb.with_user_id(current_user.id)
          else
            vqb.with_owned_by_or_shared_with_user_id(current_user.id)
          end
        end

        # TODO: undesirable table hardcoding, needed for disambiguation. Look for
        # a better approach and/or move it to the query builder
        response = {
          visualizations: vqb.with_order("visualizations.#{order}", :desc).build_paged(page, per_page).map { |v| VisualizationPresenter.new(v, current_viewer).to_poro },
          total_entries: vqb.build.count,
          total_user_entries: VisualizationQueryBuilder.new.with_type(type).with_user_id(current_user.id).build.count,
          total_likes: VisualizationQueryBuilder.new.with_type(type).with_liked_by_user_id(current_user.id).build.count,
          total_shared: VisualizationQueryBuilder.new.with_type(type).with_shared_with_user_id(current_user.id).build.count
        }
        render_jsonp(response)
      end

      private

      def default_type(types)
        types.include?(Carto::Visualization::TYPE_DERIVED) ? Carto::Visualization::TYPE_DERIVED : Carto::Visualization::TYPE_CANONICAL
      end
    end

  end

end

# frozen_string_literal: true

require_dependency "#{Rails.root}/lib/course_revision_updater"
require_dependency "#{Rails.root}/lib/article_status_manager"
require_dependency "#{Rails.root}/lib/importers/course_upload_importer"
require_dependency "#{Rails.root}/lib/data_cycle/update_logger"
require_dependency "#{Rails.root}/lib/analytics/histogram_plotter"
require_dependency "#{Rails.root}/lib/importers/revision_score_importer"
require_dependency "#{Rails.root}/lib/importers/average_views_importer"
require_dependency "#{Rails.root}/lib/errors/update_service_error_helper"
require_dependency "#{Rails.root}/lib/data_cycle/course_queue_sorting"
require_dependency "#{Rails.root}/lib/revision_data_manager"

#= Pulls in new revisions for a single course wiki timeslice and updates the corresponding records
class UpdateCourseStatsTimeslice
  include UpdateServiceErrorHelper
  include CourseQueueSorting

  def initialize(course, wiki, timeslice_start, timeslice_end)
    @course = course
    @wiki = wiki
    @timeslice_start = timeslice_start
    @timeslice_end = timeslice_end
    # If the upate was explicitly requested by a user,
    # it could be because the dates or other paramters were just changed.
    # In that case, do a full update rather than just fetching the most
    # recent revisions.
    # @full_update = full || @course.needs_update

    @start_time = Time.zone.now
    fetch_data
    update_categories
    update_article_status if should_update_article_status?
    update_average_pageviews
    update_caches
    # update_wikidata_stats if wikidata
    # This needs to happen after `update_caches` because it relies on ArticlesCourses#new_article
    # to calculate new article stats for each namespace.
    # update_wiki_namespace_stats
    # @course.update(needs_update: false)
    @end_time = Time.zone.now
    UpdateLogger.update_course(@course, 'start_time' => @start_time.to_datetime,
                                         'end_time' => @end_time.to_datetime,
                                         'sentry_tag_uuid' => sentry_tag_uuid,
                                         'error_count' => error_count)
  end

  private

  def fetch_data
    log_update_progress :start
    # Fetchs revision for each wiki
    @revisions = {}
    @course.wikis.each do |wiki|
      @revisions[wiki] = RevisionDataManager
                         .new(wiki, @course, update_service: self)
                         .fetch_revision_data_for_course(@timeslice_start, @timeslice_end)
    end
    log_update_progress :revision_scores_fetched

    # TODO: replace the logic on ArticlesCourses.update_from_course

    # TODO: note this is not wiki scoped.
    CourseUploadImporter.new(@course, update_service: self).run
    log_update_progress :uploads_imported
  end

  def update_categories
    # TODO: note this is not wiki scoped.
    Category.refresh_categories_for(@course)
    log_update_progress :categories_updated
  end

  def update_article_status
    # TODO: note this is not wiki scoped.
    ArticleStatusManager.update_article_status_for_course(@course)
    log_update_progress :article_status_updated

    # TODO: replace the logic on ModifiedRevisionsManager.new(@wiki).move_or_delete_revisions
  end

  def update_average_pageviews
    # TODO: note this is not wiki scoped. ArticlesCourses records were not created
    # by the time this runs.
    AverageViewsImporter.update_outdated_average_views(@course.articles)
    log_update_progress :average_pageviews_updated
  end

  def update_caches
    @course.wikis.each do |wiki|
      next if @revisions[wiki].length.zero?
      @revisions[wiki].group_by(&:article_id).each do |article_id, article_revisions|
        article_course = ArticlesCourses.find_or_create_by(course: @course, article_id:)
        # TODO: determine how to get the right timeslice given the start and end
        # Update cache for ArticleCorseTimeslice
        ArticleCourseTimeslice.find_or_create_by(
          article_course_id: article_course.id
        ).update_cache_from_revisions article_revisions
      end
    end

    ArticlesCourses.update_all_caches_from_timeslices(@course.articles_courses)
    # log_update_progress :articles_courses_updated
    # CoursesUsers.update_all_caches(@course.courses_users)
    # log_update_progress :courses_users_updated
    # @course.update_cache
    HistogramPlotter.delete_csv(course: @course) # clear cached structural completeness data
    log_update_progress :course_cache_updated
  end

  def update_wikidata_stats
    UpdateWikidataStatsWorker.new.perform(@course)
    log_update_progress :wikidata_stats_updated
  end

  def update_wiki_namespace_stats
    # Update each of the tracked namespaces
    @course.course_wiki_namespaces.each do |course_wiki_ns|
      wiki = course_wiki_ns.courses_wikis.wiki
      namespace = course_wiki_ns.namespace
      UpdateWikiNamespaceStats.new(@course, wiki, namespace)
    end
    # Remove stats data for any namespaces that were previously
    # tracked but are no longer tracked.
    UpdateWikiNamespaceStats.clear_untracked_namespace_data(@course)
  end

  def wikidata
    @course.wikis.find { |wiki| wiki.project == 'wikidata' }
  end

  def log_update_progress(step)
    return unless debug?
    @sentry_logs ||= {}
    @sentry_logs[step] = Time.zone.now
    Sentry.capture_message "#{@course.title} update: #{step}",
                           level: 'warning',
                           extra: { logs: @sentry_logs }
  end

  TEN_MINUTES = 600
  def should_update_article_status?
    return true if Features.wiki_ed?
    # To cut down on overwhelming the system
    # for courses with huge numbers of articles
    # to check, we skip this on Programs & Events Dashboard
    # for slow-updating courses.
    # This means we miss cases of article deletion
    # and namespace changes unless the article
    longest_update_time(@course).to_i < TEN_MINUTES
  end

  def debug?
    @course.flags[:debug_updates]
  end
end

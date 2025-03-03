# frozen_string_literal: true

require 'rails_helper'
require "#{Rails.root}/lib/timeslice_manager"

describe UpdateTimeslicesCourseWiki do
  before { stub_const('TimesliceManager::TIMESLICE_DURATION', 86400) }

  let(:course) { create(:course, start: '2018-11-24', end: '2018-11-30') }
  let(:enwiki) { Wiki.get_or_create(language: 'en', project: 'wikipedia') }
  let(:wikidata) { Wiki.get_or_create(language: nil, project: 'wikidata') }
  let(:updater) { described_class.new(course).run }
  let(:user) { create(:user, username: 'Ragesoss') }
  let(:manager) { TimesliceManager.new(course) }
  let(:wikidata_article) { create(:article, wiki: wikidata) }
  let(:article) { create(:article, wiki: enwiki) }

  context 'when some previous wiki was removed' do
    before do
      stub_wiki_validation
      # Add a user
      course.campaigns << Campaign.first
      JoinCourse.new(course:, user:, role: 0)
      manager.create_timeslices_for_new_course_wiki_records([enwiki])
      # Add articles courses and timeslices manually
      create(:articles_course, course:, article: wikidata_article)
      create(:articles_course, course:, article:)
      create(:article_course_timeslice, course:, article: wikidata_article)
      create(:article_course_timeslice, course:, article:)

      # Add course user wiki timeslices manually
      create(:course_user_wiki_timeslice, course:, user:, wiki: enwiki)
      create(:course_user_wiki_timeslice, course:, user:, wiki: wikidata)

      # Create course wiki timeslices manually for wikidata
      course.wikis << wikidata
      manager.create_timeslices_for_new_course_wiki_records([wikidata])
      course.wikis.delete(wikidata)
    end

    it 'removes existing wiki timeslices' do
      # There is one user, two articles and two wikis
      expect(course.course_wiki_timeslices.count).to eq(14)
      expect(course.course_user_wiki_timeslices.count).to eq(2)
      expect(course.article_course_timeslices.count).to eq(2)
      expect(course.articles.count).to eq(2)
      expect(course.articles_courses.count).to eq(2)

      described_class.new(course).run
      # There is one user, one article and one wiki
      expect(course.course_wiki_timeslices.count).to eq(7)
      expect(course.course_user_wiki_timeslices.count).to eq(1)
      expect(course.article_course_timeslices.count).to eq(1)
      expect(course.articles.count).to eq(1)
      expect(course.articles_courses.count).to eq(1)
    end
  end

  context 'when a new wiki was added' do
    before do
      stub_wiki_validation
      # Add a user
      course.campaigns << Campaign.first
      JoinCourse.new(course:, user:, role: 0)
      manager.create_timeslices_for_new_course_wiki_records([enwiki])
      # Add articles courses and timeslices manually
      create(:articles_course, course:, article:)
    end

    it 'adds wiki timeslices' do
      # There is one user, one article and one wiki
      expect(course.course_wiki_timeslices.count).to eq(7)
      expect(course.course_user_wiki_timeslices.count).to eq(0)
      expect(course.articles.count).to eq(1)
      expect(course.articles_courses.count).to eq(1)

      course.wikis << wikidata
      described_class.new(course).run
      # There is one user, one article and two wikis
      expect(course.course_wiki_timeslices.count).to eq(14)
      expect(course.course_user_wiki_timeslices.count).to eq(0)
      expect(course.articles.count).to eq(1)
      expect(course.articles_courses.count).to eq(1)
    end
  end

  context 'when timeslice duration changes' do
    before do
      stub_wiki_validation
      manager.create_timeslices_for_new_course_wiki_records([enwiki])
      timeslice = course.course_wiki_timeslices.where(start: '2018-11-26'.to_datetime).first
      timeslice.update(last_mw_rev_datetime: '2018-11-26 00:45:45'.to_datetime)

      first_timeslice = course.course_wiki_timeslices.where(start: '2018-11-24'.to_datetime).first
      expect(first_timeslice.end - first_timeslice.start).to eq(86400)
      limit_timeslice = course.course_wiki_timeslices.where(start: '2018-11-26'.to_datetime).first
      expect(limit_timeslice.end - limit_timeslice.start).to eq(86400)
      last_timeslice = course.course_wiki_timeslices.where(start: '2018-11-30'.to_datetime).first
      expect(last_timeslice.end - last_timeslice.start).to eq(86400)

      # Add article course timeslices manually
      create(:article_course_timeslice, course:, article:, start: '2018-11-24'.to_datetime,
      end: '2018-11-25'.to_datetime)
      create(:article_course_timeslice, course:, article:, start: '2018-11-26'.to_datetime,
      end: '2018-11-27'.to_datetime)
      create(:article_course_timeslice, course:, article:, start: '2018-11-30'.to_datetime,
      end: '2018-12-01'.to_datetime)

      # Add course user wiki timeslices manually
      create(:course_user_wiki_timeslice, course:, user:, wiki: enwiki,
      start: '2018-11-24'.to_datetime, end: '2018-11-25'.to_datetime)
      create(:course_user_wiki_timeslice, course:, user:, wiki: enwiki,
      start: '2018-11-26'.to_datetime, end: '2018-11-27'.to_datetime)
      create(:course_user_wiki_timeslice, course:, user:, wiki: enwiki,
      start: '2018-11-30'.to_datetime, end: '2018-12-01'.to_datetime)
    end

    it 'updates current and future timeslices if new timeslice duration is smaller' do
      # Update timeslice duration to 12 hours
      course.flags = { timeslice_duration: { default: 43200 } }
      course.save

      described_class.new(course).run
      first_cwt = course.course_wiki_timeslices.where(start: '2018-11-24'.to_datetime).first
      expect(first_cwt.end - first_cwt.start).to eq(86400)
      first_cuwt = course.course_user_wiki_timeslices.where(start: '2018-11-24'.to_datetime).first
      expect(first_cuwt.end - first_cuwt.start).to eq(86400)
      first_act = course.article_course_timeslices.where(start: '2018-11-24'.to_datetime).first
      expect(first_act.end - first_act.start).to eq(86400)

      limit_cwt = course.course_wiki_timeslices.where(start: '2018-11-26'.to_datetime).first
      expect(limit_cwt.end - limit_cwt.start).to eq(43200)
      # Following timeslices were deleted
      limit_cuwt = course.course_user_wiki_timeslices.where(start: '2018-11-26'.to_datetime)
      expect(limit_cuwt).to be_empty
      limit_act = course.article_course_timeslices.where(start: '2018-11-26'.to_datetime)
      expect(limit_act).to be_empty

      last_cwt = course.course_wiki_timeslices.where(start: '2018-11-30'.to_datetime).first
      expect(last_cwt.end - last_cwt.start).to eq(43200)
      # Following timeslices were deleted
      last_cuwt = course.course_user_wiki_timeslices.where(start: '2018-11-30'.to_datetime)
      expect(last_cuwt).to be_empty
      last_act = course.article_course_timeslices.where(start: '2018-11-30'.to_datetime)
      expect(last_act).to be_empty
    end

    it 'updates current and future timeslices if new timeslice duration is greater' do
      # Update timeslice duration to 2 days
      course.flags = { timeslice_duration: { default: 172800 } }
      course.save

      described_class.new(course).run

      first_cwt = course.course_wiki_timeslices.where(start: '2018-11-24'.to_datetime).first
      expect(first_cwt.end - first_cwt.start).to eq(86400)
      first_cuwt = course.course_user_wiki_timeslices.where(start: '2018-11-24'.to_datetime).first
      expect(first_cuwt.end - first_cuwt.start).to eq(86400)
      first_act = course.article_course_timeslices.where(start: '2018-11-24'.to_datetime).first
      expect(first_act.end - first_act.start).to eq(86400)

      limit_cwt = course.course_wiki_timeslices.where(start: '2018-11-26'.to_datetime).first
      expect(limit_cwt.end - limit_cwt.start).to eq(172800)
      # Following timeslices were deleted
      limit_cuwt = course.course_user_wiki_timeslices.where(start: '2018-11-26'.to_datetime)
      expect(limit_cuwt).to be_empty
      limit_act = course.article_course_timeslices.where(start: '2018-11-26'.to_datetime)
      expect(limit_act).to be_empty

      last_cwt = course.course_wiki_timeslices.where(start: '2018-11-30'.to_datetime).first
      expect(last_cwt.end - last_cwt.start).to eq(172800)
      # Following timeslices were deleted
      last_cuwt = course.course_user_wiki_timeslices.where(start: '2018-11-30'.to_datetime)
      expect(last_cuwt).to be_empty
      last_act = course.article_course_timeslices.where(start: '2018-11-30'.to_datetime)
      expect(last_act).to be_empty
    end
  end

  it 'doesnt fail if there are no timeslices for the ingestion start date' do
    manager.create_timeslices_for_new_course_wiki_records([enwiki])
    course.update(start: '2018-11-20')
    described_class.new(course).run
  end
end

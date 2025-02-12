# frozen_string_literal: true

json.call(assignment, :id, :user_id, :article_id, :role, :article_url, :sandbox_url,
          :draft_sandbox_status, :bibliography_sandbox_status, :peer_review_sandbox_status, :flags)
json.assignment_id assignment.id
json.article_title assignment.article_title.tr('_', ' ')
if assignment.article
  json.article_rating assignment.article.rating
  json.article_rating_num rating_priority(assignment.article.rating)
  json.article_pretty_rating rating_display(assignment.article.rating)
else
  json.article_rating 'does_not_exist'
  json.article_rating_num nil
  json.article_pretty_rating '∅'
end

unless assignment.wiki_id == course.home_wiki.id
  json.language assignment.wiki.language
  json.project assignment.wiki.project
end

json.username assignment.user.username if assignment.user

# Assignment Status
json.assignment_status assignment.status
json.assignment_all_statuses assignment.all_statuses

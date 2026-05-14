# UI Inventory

A map of every user-facing HTML page in the dashboard, the Rails route that
serves it, the ERB/HAML template, and the primary React component that mounts
on it (if any). Pages are grouped by area.

Notation:
- `GET /path` — `Controller#action` → `app/views/...` → React: `ComponentName`
- "Server-rendered" means the page is a plain HAML/ERB template; React may
  still appear as small embedded widgets, but the page is not a React app.
- Many "React: X" pages mount a single root component that then runs its own
  client-side React Router. Subroutes for those pages are listed indented.

The top-level React Router config is in
`app/assets/javascripts/components/util/routes.jsx`. Course and campaign
sub-tabs are routed inside `course.jsx` and `campaigns_handler.jsx`/`campaign.jsx`.

---

## Public / unauthenticated

- `GET /` — `HomeController#index` → `home/index.html.haml` — marketing page
  shown to logged-out users; authenticated users get redirected to the
  dashboard's root React mount, which renders `DetailedCampaignList`.
- `GET /explore` — `ExploreController#index` → `explore/index.html.haml` →
  React: `Explore`
- `GET /faq` — `FaqController#index` → `faq/index.html.haml` — server-rendered
- `GET /faq/:id` — `FaqController#show` — server-rendered
- `GET /faq/new`, `/faq/:id/edit` — `FaqController` — server-rendered forms
- `GET /faq_topics`, `/faq_topics/new`, `/faq_topics/:slug/edit` —
  `FaqTopicsController` — server-rendered
- `GET /private_information` — `AboutThisSiteController#private_information` —
  server-rendered

## Authentication & onboarding

- `GET /sign_in` — `ErrorsController#login_error` → `errors/login_error.html.haml`
  (this is shown when login fails or is required; the real auth handshake is
  the OAuth flow at `/users/auth/mediawiki`)
- `GET /sign_out` — `UsersController#signout` — redirect
- `GET /sign_out_oauth` — `Devise::SessionsController#destroy` — redirect
- `GET /onboarding(/*any)` — `OnboardingController#index` →
  `onboarding/index.html.haml` → React: `Onboarding`. The Onboarding component
  is itself a mini React Router with these sub-routes:
  - `/` — `Intro`
  - `/form` — `Form`
  - `/supplementary` — `Supplementary`
  - `/permissions` — `Permissions`
  - `/finish` — `Finished`

## Dashboard

- `GET /` (authenticated) and `GET /dashboard` — `DashboardController#index` →
  `dashboard/index.html.haml` → React: `DetailedCampaignList` (user's courses)
- `GET /my_account` — `DashboardController#my_account`

## Course page

The course page is one root React component, `Course`, with internal tabs
routed by React Router inside `course/course.jsx`:

- `GET /courses/:school/:titleterm(/:_subpage(/:_subsubpage(/:_subsubsubpage)))` —
  `CoursesController#show` → `courses/show.html.haml` → React: `Course`
  - `/` and `/home` and `/overview` — `OverviewHandler`
  - `/activity/*` — `ActivityHandler`
  - `/students/*` — `StudentsTabHandler`
  - `/articles/*` — `ArticlesHandler`
  - `/uploads` — `UploadsHandler`
  - `/article_finder` — `ArticleFinder` (same component reused from the
    standalone `/article_finder` page below)
  - `/timeline/*` — `TimelineHandler` (includes the assignment wizard at
    `/timeline/wizard`)
  - `/resources` — `Resources`

Shared chrome rendered inside `Course` regardless of tab:
- `CourseNavbar` — the tab bar
- `CourseAlerts` — banner-style alerts
- `EnrollCard` — enrollment modal

Notable cross-tab modals/panels:
- "Edit Course Dates" panel from the timeline tab — `timeline/meetings.jsx`
- Course creation wizard (when entered via `/timeline/wizard`) — see Course
  creation section below

## Course creation

- `GET /course_creator` — `DashboardController#index` →
  `dashboard/index.html.haml` → React: `ConnectedCourseCreator`. After
  creation, the user is redirected to the new course's timeline and the
  wizard runs there.
- `GET /copy_course` — `CopyCourseController#index` → `copy_course/index.html.haml`
  — server-rendered form (instructor-only)

Wizard content is data-driven via `WizardController`'s JSON endpoints; there
is no separate HTML route for the wizard.

## Campaigns

Campaign URLs are handled by **`CampaignsHandler`** at the top-level React
Router (`/campaigns/*`), which then renders **`Campaign`** for any specific
campaign. The tabs are partly React-routed and partly server-rendered:

- `GET /campaigns` — `CampaignsController#index` → `campaigns/index.html.haml`
  → React: `CampaignsHandler` (list of campaigns)
- `GET /campaigns/:slug` — redirects to `/programs`
- `GET /campaigns/:slug/overview` — `CampaignsController#overview` →
  `campaigns/overview.html.haml` — React widgets (`CampaignStats`,
  `WikidataOverviewStats`) embedded in a HAML page
- `GET /campaigns/:slug/programs` — `CampaignsController#programs` →
  `campaigns/programs.html.haml` — React widgets embedded; main content is
  the list of courses in the campaign
- `GET /campaigns/:slug/articles` — `CampaignsController#articles` →
  `campaigns/articles.html.haml` — server-rendered table
- `GET /campaigns/:slug/users` — `CampaignsController#users` →
  `campaigns/users.html.haml` — server-rendered list
- `GET /campaigns/:slug/alerts` — `CampaignsController#alerts` →
  `campaigns/alerts.html.haml` → React: `CampaignAlerts` (sub-route inside
  `Campaign`)
- `GET /campaigns/:slug/ores_plot` — `CampaignsController#ores_plot` →
  `campaigns/ores_plot.html.haml` → React: `CampaignOresPlot` (sub-route
  inside `Campaign`)
- `GET /campaigns/:slug/edit` — `CampaignsController#edit` →
  `campaigns/edit.html.haml` — server-rendered edit form

## Tagged courses

Same shape as campaigns, narrower:

- `GET /tagged_courses/:tag` — redirects to `/programs`
- `GET /tagged_courses/:tag/programs` — `TaggedCoursesController#programs` →
  `tagged_courses/programs.html.haml` → React: `TaggedCoursesStats`
- `GET /tagged_courses/:tag/articles` — `TaggedCoursesController#articles` →
  `tagged_courses/articles.html.haml` — server-rendered
- `GET /tagged_courses/:tag/alerts` — `TaggedCoursesController#alerts` →
  `tagged_courses/alerts.html.haml` → React: `TaggedCourseAlerts`

## Course listings

- `GET /active_courses` — `ActiveCoursesController#index` →
  `active_courses/index.html.haml` → React: `ActiveCoursesHandler`
- `GET /unsubmitted_courses` — `UnsubmittedCoursesController#index` →
  `unsubmitted_courses/index.html.haml` — server-rendered table
- `GET /courses_by_wiki/:language.:project(.org)` — `CoursesByWikiController#show`
  → `courses_by_wiki/show.html.haml` → React: `CoursesByWikiHandler`

## Article finder

- `GET /article_finder` — `ArticleFinderController#index` →
  `article_finder/index.html.haml` → React: `ArticleFinder`
  (Same component is also available inside the course page at
  `/courses/.../article_finder`.)

## Training

Training has both server-rendered library/index pages and a React app for
walking through individual modules.

- `GET /training` — `TrainingController#index` → `training/index.html.haml` —
  server-rendered (library directory)
- `GET /training/:library_id` — `TrainingController#show` →
  `training/show.html.haml` — server-rendered (library overview)
- `GET /training/:library_id/:module_id` — `TrainingController#training_module`
  → `training/training_module.html.haml` — server-rendered (module overview)
- `GET /training/:library_id/:module_id/*` — `TrainingController#slide_view` →
  `training/slide_view.html.haml` → React: `TrainingApp` (the slide viewer)
- `GET /training_module_drafts(/*any)` — `TrainingModuleDraftsController` →
  `training_module_drafts/index.html.haml` → React: `TrainingModuleComposer`

## Surveys

Almost entirely server-rendered (Rapidfire gem under the hood). The list of
surveys is the only piece currently locked at axe-clean.

- `GET /surveys` — `SurveysController#index` → `surveys/index.html.haml` —
  server-rendered (admin list)
- `GET /surveys/new` — server-rendered (new survey form)
- `GET /surveys/:id` — server-rendered (survey show)
- `GET /surveys/:id/edit` — server-rendered
- `GET /surveys/:id/question_group` — server-rendered (question-group editor)
- `GET /surveys/:id/optout` — server-rendered (respondent opt-out flow)
- `GET /surveys/select_course/:id` — server-rendered (respondent course
  selection)
- `GET /surveys/results` — server-rendered (results index)
- `GET /survey/results/:id` — `SurveyResultsController#results` —
  server-rendered (individual survey results)
- `GET /survey/responses` — `SurveyResponsesController#index` —
  server-rendered
- `GET /surveys/assignments`, `/new`, `/:id`, `/:id/edit` —
  `SurveyAssignmentsController` — server-rendered (admin: who gets the
  survey and when)
- Rapidfire mount under `/surveys/rapidfire/...` provides the
  question/question-group CRUD UI.

## User profiles

- `GET /users/:username` — `UserProfilesController#show` →
  `user_profiles/show.html.haml` → React: `UserProfile`
- `GET /users` — `UsersController#index` → `users/index.html.haml` —
  server-rendered (admin lookup of users by ID)

## Admin

The admin index is a HAML page of links. Most admin tools are individual
small HAML pages with forms; a few are full React apps.

- `GET /admin` — `AdminController#index` → `admin/index.html.haml` —
  server-rendered (link directory to all admin tools below)
- `GET /settings` — `SettingsController#index` → `settings/index.html.haml`
  → React: `SettingsHandler` (admin-list, special-users, etc. — these are
  React tabs/sub-views, not separate Rails routes)
- `GET /alerts_list` — `AlertsListController#index` →
  `alerts_list/index.html.haml` → React: `AdminAlerts`
- `GET /alerts_list/:id` — `AlertsListController#show` →
  `alerts_list/show.html.haml` — server-rendered
- `GET /ai_edit_alerts_stats/select_campaign` —
  `AiEditAlertsStatsController#select_campaign` — server-rendered (campaign
  picker)
- `GET /ai_edit_alerts_stats/:campaign_slug` —
  `AiEditAlertsStatsController#index` →
  `ai_edit_alerts_stats/index.html.haml` → React: `AlertsStats`
- `GET /tickets/dashboard` — `TicketsController#dashboard` →
  `tickets/dashboard.html.haml` → React: `TicketsHandler`
- `GET /tickets/dashboard/:id` — same controller/template → React:
  `TicketShowHandler`
- `GET /recent-activity(/*any)` — `RecentActivityController#index` →
  `recent_activity/index.html.haml` → React: `RecentActivityHandler`
  (admin-only)
- `GET /requested_accounts` — `RequestedAccountsController#index` —
  server-rendered (list)
- `GET /requested_accounts/:course_slug` —
  `RequestedAccountsController#show` — server-rendered
- `GET /requested_accounts_campaigns/:campaign_slug` —
  `RequestedAccountsCampaignsController#index` — server-rendered
- `GET /requested_accounts_campaigns/:campaign_slug/create` — same
  controller, `#create_accounts` — server-rendered
- `GET /mass_enrollment/:course_id` — `MassEnrollmentController#index` →
  `mass_enrollment/index.html.haml` — server-rendered (paste a list of
  usernames to enroll)
- `GET /update_username` — `UpdateUsernameController#index` —
  server-rendered (admin tool to rename a user)
- `GET /timeslice_duration` — `TimesliceDurationController#index` —
  server-rendered (form)
- `GET /timeslice_duration/update` — `TimesliceDurationController#show` —
  server-rendered (results)
- `GET /mass_email/term_recap` — `MassEmailTermRecapController#index` —
  server-rendered (admin email tool)
- `GET /revision_ai_scores_stats` — `RevisionAiScoresStatsController#index`
  → `revision_ai_scores_stats/index.html.haml` → React:
  `RevisionAiScoresStats`
- `GET /revision_feedback` — `RevisionFeedbackController#index` →
  `revision_feedback/index.html.haml` — server-rendered
- `GET /ai_tools` — `AiToolsController#show` → `ai_tools/show.html.haml` —
  server-rendered (form + results)
- `GET /status` — `SystemStatusController#index` →
  `system_status/index.html.haml` — server-rendered (queue + worker
  metrics)
- `GET /mailer_previews` — `MailerPreviewsController#index` —
  server-rendered (public transparency page listing email templates;
  individual mailer-preview routes link out from here)
- `GET /styleguide` — `StyleguideController#index` — server-rendered design
  system reference

## Analytics

- `GET /analytics(/*any)` — `AnalyticsController#index` →
  `analytics/index.html.haml` — server-rendered (forms with results)
- `GET /usage` — `AnalyticsController#usage` — server-rendered

## Feedback

- `GET /feedback` — `FeedbackFormResponsesController#new` —
  server-rendered (user-facing form, shown on most pages via a sidebar
  link)
- `GET /feedback/confirmation` — server-rendered
- `GET /feedback_form_responses` — admin list — server-rendered
- `GET /feedback_form_responses/:id` — admin show — server-rendered

## Error pages

- `GET /errors/file_not_found`, `/errors/unprocessable`,
  `/errors/internal_server_error`, `/errors/incorrect_passcode`,
  `/errors/login_error` — `ErrorsController` — server-rendered
- `GET /404`, `/422`, `/500` — same controller via the error matchers

---

## Cross-cutting React components

These don't have their own routes but show up on many pages and are worth
knowing about when planning audits or refactors:

- `Confirm` — modal confirmation dialog
- `Modal` — generic modal wrapper used by Confirm and many others
- `CourseNavbar`, `CampaignNavbar` — tab bars
- `CourseAlerts`, `CampaignAlerts` — banner alerts
- `EnrollCard` — course enrollment modal
- `CampaignStats`, `CampaignStatsDownloadModal`, `WikidataOverviewStats`,
  `CampaignOresPlot` — campaign-page widgets
- `DatePicker` (wraps react-day-picker 7.x) — used everywhere dates are
  edited
- `CreatableInput` (wraps react-select 5.x) — used wherever a freeform
  combobox is needed
- `Notifications` — toast/notification queue (mounted globally)

## Stack notes

- React Router v6 throughout. Top-level routes in `util/routes.jsx`; many
  pages nest a second router (course, campaign, onboarding, training,
  recent-activity, settings, tickets, training-module-drafts).
- Redux + react-redux for shared state. Course, campaign, articles,
  assignments, users, and validations live in the store.
- React components are lazy-loaded via `React.lazy` and `Suspense` at the
  top level, so each major area splits into its own webpack chunk.
- Mailer preview routes and JSON endpoints are intentionally not listed
  here; this doc covers user-visible HTML pages only.

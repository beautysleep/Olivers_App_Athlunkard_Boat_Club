# Concept
Concept

The concept is a web application/service for members of a rowing club.

The service should automate useful parts of the rowing-club experience that are currently handled manually, communicated informally, or require members/coaches to check several separate sources.

The first feature should answer questions such as:

Is it safe to row today?
Is it safe to row over the next 10 days?
What days/times are likely to be suitable for rowing?

The app should present this in a simple, member-friendly format, likely as a calendar or day-by-day view where each day is colour-coded based on the safety calculation.

Example output concept:

Green: likely safe to row
Amber: caution / conditions need review
Red: unsafe or unsuitable
Grey: insufficient data

The app should be designed so it can later be extended beyond rowing-condition checks. A future example is allowing coaches to provide gym plans or training plans to athletes/coachees through the same web app.

The first version should focus on the rowing-safety feature, while keeping the design simple enough that additional club features can be added later without rebuilding the application from scratch.

## Goal
The primary goal of the application is to help rowing-club members improve as athletes.

This means improving both:

Rowing skill, by making sure athletes get onto the water when conditions are suitable
Physical capacity, by later supporting structured land-based training such as gym plans, strength work, power development, and rowing-machine performance

The first version supports this goal by reducing missed rowing opportunities.

The club has access to a river that often has good rowing conditions, but suitable windows can be missed because the checks are manual, distributed across several information sources, and easy to forget. The application should help the club identify good rowing opportunities further in advance and notify the relevant people so those opportunities are more likely to be used.

The core operational goal is:

Do not miss good rowing opportunities because nobody checked the conditions early enough.

The broader athlete-development goal is:

Improve the athletes within the club's remit by supporting better water training and, later, better land-based training.

Secondary learning goal

A secondary goal is to learn how to develop software applications by describing the application clearly enough that coding agents can implement it with limited direct coding from the user.

The user has previously written code directly and been heavily involved in implementation. This project is also a test of whether good planning, clear Markdown documentation, and small well-described increments can allow coding agents to build the application reliably.

Delivery constraint

The application should be developed in small pieces.

The project should not attempt to deliver every feature at once. The preferred approach is incremental delivery: small, understandable, testable builds that can be reviewed and corrected before the next piece is added.

## Problem being solved
The broader problem is a lack of centralised knowledge.

Certain people in the club know a lot about the conditions needed for rowing, the conditions that help athletes improve their form, and the conditions that suit specific types of training sessions. Much of this knowledge currently lives in the heads of experienced coaches, experienced athletes, or long-standing club members.

The application should help capture and share that knowledge so more members can benefit from it.

The aim is to create a system where coaches or experienced members can input or encode their knowledge, and where members can go to one web application to see the practical wisdom of the most experienced people in the club.

The first feature focuses on one specific version of this problem:

When should we go out on the water, are the conditions suitable, and who is available?

At the moment, this is solved manually through phone calls, text messages, informal judgement, and different people checking different sources on different days.

The club misses perfectly good rowing-condition days because the checking process is manual, distributed, and fragile. Suitable rowing windows can be missed when:

Weather conditions are not checked early enough
Tide and daylight conditions are not checked together
River or dam-release information is not reviewed in time
Experienced people are not available to make the judgement
The right people are not notified early enough to organise a session
Responsibility for checking conditions is informal or unclear
Athlete availability is not known early enough

The first version of the application should reduce this failure mode by centralising the decision around:

What day and time looks suitable for rowing
Whether the rowing conditions are suitable
Whether athletes are available
Whether the relevant people have been notified

The deeper goal is not only to automate a weather check. The deeper goal is to capture club knowledge and make good rowing decisions easier, earlier, and less dependent on informal communication.

## Intended users
Coaches / experienced members
Athletes / coached members
Two-tier notification flow
Approximate user counts
Age and availability patterns
Calendar-view need
Technical comfort level
Open decision around whether accounts are needed

## Core workflow
The primary workflow for the first version is the rowing-session opportunity workflow.

The app should look ahead for suitable rowing windows. When weather, tide, daylight, river, and other relevant conditions suggest that rowing may be suitable, the app should identify that as a potential session opportunity.

Before sending any new notification, the app should check whether a session already exists at roughly the same date and time. If a session is already scheduled for that approximate window, the app should not create another duplicate opportunity or send another duplicate notification.

The simplest workflow is:

The app detects a potential good rowing window.
The app checks whether a session already exists at roughly that time.
If no matching session exists, the app notifies the relevant coaches or experienced members.
One or more coaches respond to say they are available.
Once a coach is available, athletes are notified that a possible coached/supervised session is available.
Athletes respond to say whether they will attend.
When enough athletes have accepted, for example four athletes, the coach can confirm the session.
Once confirmed, the session is marked on the calendar as confirmed.
Athletes who accepted are notified that the session is confirmed.

The coach should also be able to cancel the session at any time, even after previously accepting or confirming it.

If a confirmed or pending session is cancelled:

The session is marked as cancelled.
Athletes who had accepted are notified that the session has been cancelled.
The calendar should show that the session is no longer going ahead.

The first version should focus on this core workflow. Other features can be built around it later.

The key session states are likely to be:

Opportunity detected
Coach availability requested
Coach available
Athlete availability requested
Pending enough athletes
Confirmed
Cancelled
## Data involved
Environmental data
Ardnacrusha / river-flow data
Member data
Coach availability
Athlete availability
Session/event data
Condition assessment data
Provisional BigQuery / Cloud Storage approach

The first version of the application needs data from several external sources and from the rowing club itself.

The data can be grouped into:

Environmental condition data
River / dam-release data
Club member data
Session / event data
Notification and response data

Environmental condition data:

The application will need to connect to weather and environmental data sources for the rowing location. Required or likely data points include: Geographic coordinates for the rowing location, wind speed for those coordinates, wind direction for those coordinates, rainfall over a previous time window, for example the previous ten hours, rainfall forecast for a future time window, rainfall forecast at or around a proposed rowing time, tide times, tide heights, sunrise time, sunset time. These data points may come from separate APIs. For example, weather, tides, and sunrise or sunset information may each require different data sources. The application should store collected environmental data so it can be reviewed later and potentially used for analysis, tuning, or forecasting.

Ardnacrusha or river-flow data:

The application should include data from Ardnacrusha where possible. Ardnacrusha data is expected to be less live than weather API data. Weather APIs may be queried at any time for current or forecast information, while Ardnacrusha release information may only be published for a limited number of days in advance. The current assumption is that Ardnacrusha does not provide a formal API. The data may need to be scraped from the relevant website, if technically and legally acceptable. The relevant data point is expected to be the planned volume of water released, such as litres, gallons, or another published flow or release measure. The application should eventually apply a threshold: If planned or current water release is above a defined threshold, the river flow should be treated as too high for rowing. If Ardnacrusha data is not available for a future time, the first version may need to assume conditions are safe for that factor, while continuing to check for newly available Ardnacrusha information as often as is reasonable. This assumption should be treated carefully because missing dam-release data could create false confidence.

Club member data:

The application will need to know who the users are so it can notify the right people and collect availability responses. A simple first model may use one members table rather than separate athlete and coach tables. Possible member fields: member ID, name, role or roles (for example, coach, experienced member, athlete), notification contact method or linked notification identifier, active or inactive status. The first version should avoid collecting unnecessary personal information.

Coach availability data:

The application needs to know whether coaches or experienced members are available for a proposed rowing window. Possible data points include: proposed session ID, coach or member ID, proposed date and time, availability response,

The data involved section is as follows:

The first version of the application needs data from several external sources and from the rowing club itself.

The data can be grouped into:

Environmental condition data
River / dam-release data
Club member data
Session / event data
Notification and response data

Environmental condition data:

The application will need to connect to weather and environmental data sources for the rowing location.

Required or likely data points include:

Geographic coordinates for the rowing location
Wind speed for those coordinates
Wind direction for those coordinates
Rainfall over a previous time window, for example the previous 10 hours
Rainfall forecast for a future time window
Rainfall forecast at or around a proposed rowing time
Tide times
Tide heights
Sunrise time
Sunset time

These data points may come from separate APIs. For example, weather, tides, and sunrise/sunset information may each require different data sources.

The application should store collected environmental data so it can be reviewed later and potentially used for analysis, tuning, or forecasting.

Ardnacrusha / river-flow data:

The application should include data from Ardnacrusha where possible.

Ardnacrusha data is expected to be less live than weather API data. Weather APIs may be queried at any time for current or forecast information, while Ardnacrusha release information may only be published for a limited number of days in advance.

The current assumption is that Ardnacrusha does not provide a formal API. The data may need to be scraped from the relevant website, if technically and legally acceptable.

The relevant data point is expected to be the planned volume of water released, such as litres, gallons, or another published flow/release measure.

The application should eventually apply a threshold:

If planned or current water release is above a defined threshold, the river flow should be treated as too high for rowing.

If Ardnacrusha data is not available for a future time, the first version may need to assume conditions are safe for that factor, while continuing to check for newly available Ardnacrusha information as often as is reasonable.

This assumption should be treated carefully because missing dam-release data could create false confidence.

Club member data:

The application will need to know who the users are so it can notify the right people and collect availability responses.

A simple first model may use one members table rather than separate athlete and coach tables.

Possible member fields:

Member ID
Name
Role or roles, for example coach, experienced member, athlete
Notification contact method or linked notification identifier
Active / inactive status

The first version should avoid collecting unnecessary personal information.

Coach availability data:

The application needs to know whether coaches or experienced members are available for a proposed rowing window.

Possible data points include:

Proposed session ID
Coach/member ID
Proposed date and time
Availability response
response timestamp
cancellation status if a coach later withdraws.

Athlete availability data:

The application needs to know whether athletes are available for a proposed or confirmed session. Possible data points include: proposed session ID, athlete or member ID, availability response, response timestamp, cancellation or withdrawal status if an athlete later withdraws. This may be represented as a separate acceptance or status table rather than being stored directly on the event itself.

Session or event data:

The application will need data about upcoming sessions and detected opportunities. This is needed to avoid duplicate notifications, show sessions on a calendar, track whether a session is only an opportunity, pending, confirmed, or cancelled, track how many athletes have accepted, notify the right people when the session status changes. Possible event or session fields: session ID, proposed date and time, status, related condition score or suitability result, coach or member ID if a coach has accepted, minimum athlete count required for confirmation, current accepted athlete count, created timestamp, confirmed timestamp, cancelled timestamp, cancellation reason if available. The exact event model is not decided yet.

Condition assessment data:

The application may need a table or derived dataset that records the condition assessment for a given date or time window. Possible fields: assessment ID, date or time window, location, wind result, rainfall result, tide result, daylight result, Ardnacrusha or river-flow result, overall status, for example suitable, caution, unsuitable, or unknown, reason summary, data completeness flag, assessment timestamp.

Possible storage approach:

A provisional storage approach is Google BigQuery for structured tables and logs, Google Cloud Storage for file-like items if file storage is later needed. At the moment, there are no clear file-storage requirements. Possible BigQuery-style tables include members, condition assessments, weather wind log, weather rainfall log, tide log, sunrise sunset log, Ardnacrusha release log, sessions, coach availability, athlete availability. This is only an early data model. It should not be treated as the final schema. The first implementation should use the simplest data structure that supports the first workflow reliably.

## Constraints
The constraints I can think of at the moment are:
- The Webapp mus be useable on Android and iOS first.
- I think it whould be a downloadable app primarily and secondly a website. Because notifications are necessary for the use so a downloaded app seems right, I had though web app would be fine but for now it seems best to be an app. 
- The I must be built and deployed on GCP. I was hoping for google cloud run but maybe it should be firebase

## Non-goals
- Replace coach judgement
- Guarantee that rowing is safe
- Manage every club activity
- Provide full training-plan management
- Track athlete performance
- Replace WhatsApp or all club communication
- Build a complete membership-management system
- Support every possible river/weather condition from day one

## Assumptions

## Risks / failure modes

## Open questions

## Simplest possible version
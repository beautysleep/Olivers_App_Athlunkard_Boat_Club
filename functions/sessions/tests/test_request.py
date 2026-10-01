from datetime import datetime, timezone

import pytest

from models import GREEN
from request import (
    CancelRequest,
    DeviceTokenRequest,
    MalformedRequest,
    ProposalRequest,
    ResponseRequest,
    read_cancel_request,
    read_device_token_request,
    read_proposal_request,
    read_response_request,
)


class TestReadProposalRequest:
    def test_a_well_formed_proposal_carries_everything_needed(self):
        proposal = read_proposal_request(
            {
                "meeting_time": "2026-09-20T06:00:00.000Z",
                "high_tide_time": "2026-09-20T06:41:00.000Z",
                "condition_rating": GREEN,
            }
        )

        assert proposal == ProposalRequest(
            meeting_time=datetime(2026, 9, 20, 6, 0, tzinfo=timezone.utc),
            high_tide_time=datetime(2026, 9, 20, 6, 41, tzinfo=timezone.utc),
            condition_rating=GREEN,
        )

    @pytest.mark.parametrize(
        "body",
        [
            None,
            {},
            {"high_tide_time": "2026-09-20T06:41:00.000Z", "condition_rating": GREEN},
            {"meeting_time": "2026-09-20T06:00:00.000Z", "condition_rating": GREEN},
            {
                "meeting_time": "2026-09-20T06:00:00.000Z",
                "high_tide_time": "2026-09-20T06:41:00.000Z",
            },
            {
                "meeting_time": "not a time",
                "high_tide_time": "2026-09-20T06:41:00.000Z",
                "condition_rating": GREEN,
            },
            {
                "meeting_time": "2026-09-20T06:00:00.000Z",
                "high_tide_time": "2026-09-20T06:41:00.000Z",
                "condition_rating": "stormy",
            },
        ],
        ids=[
            "no body at all",
            "empty body",
            "no meeting time",
            "no tide time",
            "no rating",
            "unparseable meeting time",
            "an unrecognised rating",
        ],
    )
    def test_an_incomplete_or_malformed_proposal_is_refused(self, body):
        with pytest.raises(MalformedRequest):
            read_proposal_request(body)


class TestReadResponseRequest:
    def test_a_well_formed_response_carries_the_session_and_the_answer(self):
        response = read_response_request({"session_id": "abc123", "accept": True})

        assert response == ResponseRequest(session_id="abc123", accept=True)

    @pytest.mark.parametrize(
        "body",
        [
            None,
            {},
            {"accept": True},
            {"session_id": "abc123"},
            {"session_id": "", "accept": True},
            {"session_id": "abc123", "accept": "yes"},
        ],
        ids=[
            "no body at all",
            "empty body",
            "no session id",
            "no answer",
            "blank session id",
            "a non-boolean answer",
        ],
    )
    def test_an_incomplete_or_malformed_response_is_refused(self, body):
        with pytest.raises(MalformedRequest):
            read_response_request(body)


class TestReadCancelRequest:
    def test_a_well_formed_cancellation_carries_the_session_and_the_choice(self):
        cancellation = read_cancel_request(
            {"session_id": "abc123", "pivot_to_land": True}
        )

        assert cancellation == CancelRequest(session_id="abc123", pivot_to_land=True)

    @pytest.mark.parametrize(
        "body",
        [
            None,
            {},
            {"pivot_to_land": True},
            {"session_id": "abc123"},
            {"session_id": "abc123", "pivot_to_land": "yes"},
        ],
        ids=[
            "no body at all",
            "empty body",
            "no session id",
            "no pivot choice",
            "a non-boolean pivot choice",
        ],
    )
    def test_an_incomplete_or_malformed_cancellation_is_refused(self, body):
        with pytest.raises(MalformedRequest):
            read_cancel_request(body)


class TestReadDeviceTokenRequest:
    def test_a_well_formed_registration_carries_the_token(self):
        registration = read_device_token_request({"token": "fcm-token-abc"})

        assert registration == DeviceTokenRequest(token="fcm-token-abc")

    @pytest.mark.parametrize(
        "body",
        [None, {}, {"token": ""}, {"token": "   "}],
        ids=["no body at all", "empty body", "blank token", "whitespace-only token"],
    )
    def test_a_missing_or_blank_token_is_refused(self, body):
        with pytest.raises(MalformedRequest):
            read_device_token_request(body)

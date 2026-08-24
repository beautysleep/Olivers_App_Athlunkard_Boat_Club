import pytest

from membership import (
    UnknownInviteCode,
    build_member_document,
    role_for_code,
)
from models import ATHLETE, COACH, PARENT

CODES = {
    "row-coach-2026": {"role": COACH, "label": "Coaches"},
    "row-crew-2026": {"role": ATHLETE, "label": "Athletes"},
    "row-family-2026": {"role": PARENT, "label": "Parents"},
}


def lookup(code):
    return CODES.get(code)


class TestRoleForCode:
    def test_each_code_grants_the_role_it_was_issued_for(self):
        assert role_for_code("row-coach-2026", lookup) == COACH
        assert role_for_code("row-crew-2026", lookup) == ATHLETE
        assert role_for_code("row-family-2026", lookup) == PARENT

    def test_a_code_nobody_issued_grants_nothing(self):
        with pytest.raises(UnknownInviteCode):
            role_for_code("let-me-in", lookup)

    def test_an_empty_code_is_not_a_shortcut(self):
        with pytest.raises(UnknownInviteCode):
            role_for_code("", lookup)

    def test_codes_are_matched_whole_and_case_insensitively(self):
        assert role_for_code("ROW-Coach-2026", lookup) == COACH
        with pytest.raises(UnknownInviteCode):
            role_for_code("row-coach", lookup)

    def test_a_code_document_without_a_role_grants_nothing(self):
        with pytest.raises(UnknownInviteCode):
            role_for_code("broken", lambda code: {"label": "Oops"})


class TestMemberDocument:
    def test_a_member_is_stored_by_the_identity_they_signed_in_with(self):
        document = build_member_document(
            uid="abc123",
            email="saoirse@athlunkard.club",
            display_name="Saoirse Walsh",
            role=ATHLETE,
        )

        assert document["display_name"] == "Saoirse Walsh"
        assert document["email"] == "saoirse@athlunkard.club"
        assert document["role"] == ATHLETE
        assert "uid" not in document, "the uid is the document key, not a field"

    def test_a_parent_records_the_athlete_they_are_linked_to(self):
        document = build_member_document(
            uid="p1",
            email="liam@athlunkard.club",
            display_name="Liam O'Brien",
            role=PARENT,
            child_uid="abc123",
        )

        assert document["child_uid"] == "abc123"

    def test_only_a_parent_carries_a_child(self):
        document = build_member_document(
            uid="c1",
            email="coach@athlunkard.club",
            display_name="Niamh Ryan",
            role=COACH,
            child_uid="abc123",
        )

        assert document["child_uid"] is None

    def test_a_blank_display_name_is_refused_rather_than_stored(self):
        with pytest.raises(ValueError):
            build_member_document(
                uid="x", email="x@y.z", display_name="   ", role=ATHLETE
            )

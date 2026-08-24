import pytest

from request import ClaimRequest, MalformedClaim, read_claim


def test_a_well_formed_claim_carries_everything_the_profile_needs():
    claim = read_claim(
        {"invite_code": "row-crew-2026", "display_name": "Saoirse Walsh"}
    )

    assert claim == ClaimRequest(
        invite_code="row-crew-2026", display_name="Saoirse Walsh", child_uid=None
    )


def test_a_parent_may_name_the_athlete_they_are_linked_to():
    claim = read_claim(
        {
            "invite_code": "row-family-2026",
            "display_name": "Liam O'Brien",
            "child_uid": "abc123",
        }
    )

    assert claim.child_uid == "abc123"


@pytest.mark.parametrize(
    "body",
    [
        None,
        {},
        {"invite_code": "row-crew-2026"},
        {"display_name": "Saoirse Walsh"},
        {"invite_code": "", "display_name": "Saoirse Walsh"},
        {"invite_code": "row-crew-2026", "display_name": ""},
    ],
    ids=[
        "no body at all",
        "empty body",
        "no name",
        "no code",
        "blank code",
        "blank name",
    ],
)
def test_an_incomplete_claim_is_refused_before_any_lookup(body):
    with pytest.raises(MalformedClaim):
        read_claim(body)

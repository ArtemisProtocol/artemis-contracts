import pytest

from brownie import accounts, reverts, chain


@pytest.fixture
def mis(ArtemisToken):
    token = accounts[0].deploy(ArtemisToken)
    token.mint(accounts[0], 1e30)
    token.transfer(accounts[1], 1e25, {'from': accounts[0]})
    token.transfer(accounts[2], 1e25, {'from': accounts[0]})
    token.transfer(accounts[3], 1e25, {'from': accounts[0]})
    return token


@pytest.fixture
def wone(ArtemisToken):
    token = accounts[0].deploy(ArtemisToken)
    token.mint(accounts[0], 1e30)
    token.transfer(accounts[1], 1e25, {'from': accounts[0]})
    token.transfer(accounts[2], 1e25, {'from': accounts[0]})
    token.transfer(accounts[3], 1e25, {'from': accounts[0]})
    return token


@pytest.fixture
def rvrs(ArtemisToken):
    token = accounts[0].deploy(ArtemisToken)
    token.mint(accounts[0], 1e30)
    return token


@pytest.fixture
def ifo1(IFOwithCollateral, mis, wone, rvrs, chain):
    offeringAmount = int(1e18 * 1000)

    IFO = IFOwithCollateral.deploy(
        wone,
        rvrs,
        chain.height+2,
        chain.height+100,
        offeringAmount,
        int(1e18 * 1000),
        accounts[0],
        mis,
        int(1e18 * 800),
        {'from': accounts[0]}
    )

    # Send ifo contract enough rvrs
    rvrs.transfer(IFO, offeringAmount, {'from': accounts[0]})

    return IFO



def test_ifo1_user_workflow_green_path(ifo1, mis, wone, rvrs):
    """Test the normal workflow assuming everything happens in the right order"""

    # Deposit Collateral
    assert not ifo1.hasCollateral(accounts[1]), "User shouldn't have collateral staked yet"

    mis.approve(ifo1, 1e30, {'from': accounts[1]})
    mis_bal_before = mis.balanceOf(accounts[1])

    ifo1.depositCollateral({'from': accounts[1]})

    mis_bal_after = mis.balanceOf(accounts[1])
    assert int((mis_bal_before - mis_bal_after)/1e18) == 800, "MIS balance is messed up"
    assert ifo1.hasCollateral(accounts[1]), "User didn't get credit for staking collateral"

    # Deposit WONE
    wone.approve(ifo1, 1e30, {'from': accounts[1]})
    wone_bal_before = wone.balanceOf(accounts[1])

    ifo1.deposit(int(1e20), {'from': accounts[1]})

    wone_bal_after = wone.balanceOf(accounts[1])
    assert int((wone_bal_before - wone_bal_after)/1e18) == 100, "WONE balance is messed up"
    assert ifo1.getUserAllocation(accounts[1]) == 1000000, "User didn't get credit for depositing WONE"

    # Validate harvest doesn't work yet - this should revert
    with reverts('not harvest time'):
        ifo1.harvest({'from': accounts[1]})

    # Go to end of IFO and harvest
    chain.mine(100)
    mis_bal_before = mis.balanceOf(accounts[1])
    wone_bal_before = wone.balanceOf(accounts[1])
    rvrs_bal_before = rvrs.balanceOf(accounts[1])

    ifo1.harvest({'from': accounts[1]})

    mis_bal_after = mis.balanceOf(accounts[1])
    wone_bal_after = wone.balanceOf(accounts[1])
    rvrs_bal_after = rvrs.balanceOf(accounts[1])

    assert int((mis_bal_after - mis_bal_before)/1e18) == 800, "MIS balance is messed up"
    assert int((wone_bal_after - wone_bal_before)/1e18) == 0, "WONE balance is messed up"
    assert int((rvrs_bal_after - rvrs_bal_before)/1e18) == 100, "RVRS balance is messed up"


def test_ifo1_allocation(ifo1, mis, wone, rvrs):
    """Test refunds work with overflow"""

    mis.approve(ifo1, 1e30, {'from': accounts[1]})
    mis.approve(ifo1, 1e30, {'from': accounts[2]})
    mis.approve(ifo1, 1e30, {'from': accounts[3]})

    ifo1.depositCollateral({'from': accounts[1]})
    ifo1.depositCollateral({'from': accounts[2]})
    ifo1.depositCollateral({'from': accounts[3]})

    # Deposit WONE
    wone.approve(ifo1, 1e30, {'from': accounts[1]})
    wone.approve(ifo1, 1e30, {'from': accounts[2]})
    wone.approve(ifo1, 1e30, {'from': accounts[3]})

    ifo1.deposit(int(1*1e21), {'from': accounts[1]})
    ifo1.deposit(int(2*1e21), {'from': accounts[2]})
    ifo1.deposit(int(7*1e21), {'from': accounts[3]})

    # Go to end of IFO and harvest
    chain.mine(100)
    wone_bal_before1 = wone.balanceOf(accounts[1])
    wone_bal_before2 = wone.balanceOf(accounts[2])
    wone_bal_before3 = wone.balanceOf(accounts[3])

    ifo1.harvest({'from': accounts[1]})
    ifo1.harvest({'from': accounts[2]})
    ifo1.harvest({'from': accounts[3]})

    wone_bal_after1 = wone.balanceOf(accounts[1])
    wone_bal_after2 = wone.balanceOf(accounts[2])
    wone_bal_after3 = wone.balanceOf(accounts[3])

    rvrs_bal_after1 = rvrs.balanceOf(accounts[1])
    rvrs_bal_after2 = rvrs.balanceOf(accounts[2])
    rvrs_bal_after3 = rvrs.balanceOf(accounts[3])

    assert int((wone_bal_after1 - wone_bal_before1)/1e18) == 900, "1 WONE balance is messed up"
    assert int((wone_bal_after2 - wone_bal_before2)/1e18) == 1800, "2 WONE balance is messed up"
    assert int((wone_bal_after3 - wone_bal_before3)/1e18) == 6300, "3 WONE balance is messed up"

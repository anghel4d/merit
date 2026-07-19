// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract IqRecord {
    struct IqResults {
        uint16 score;
        uint16[] subscores;
        uint64 date;            // Unix timestamp
        address institution;    // must be in approved registry
    }

    uint64 public constant STALENESS_LIMIT = 365 days;
    uint64 public constant GRACE_PERIOD = 30 days;

    mapping(address => IqResults[]) private iqHistory;
    mapping(address => bool) public approvedInstitution; // maintained by judgement

    // Only an approved institution may write, and only for the member it examined.
    // Dates must be strictly increasing per member: no backdating.
    function recordTest(
        address member,
        uint16 score,
        uint16[] calldata subscores,
        uint64 date
    ) external {
        require(approvedInstitution[msg.sender], "not an approved institution");
        IqResults[] storage h = iqHistory[member];
        if (h.length > 0) {
            require(date > h[h.length - 1].date, "backdated test");
        }
        require(date <= block.timestamp, "future-dated test");
        h.push(IqResults(score, subscores, date, msg.sender));
    }

    // Latest result. Reverts if the member has never been tested.
    function latestIq(address member) public view returns (uint16) {
        IqResults[] storage h = iqHistory[member];
        require(h.length > 0, "no test on record");
        return h[h.length - 1].score;
    }

    // Lateness: true while the latest test is within the annual limit plus grace.
    function isCurrent(address member) public view returns (bool) {
        IqResults[] storage h = iqHistory[member];
        if (h.length == 0) return false;
        return block.timestamp - h[h.length - 1].date
            <= STALENESS_LIMIT + GRACE_PERIOD;
    }

    // Seconds overdue past the annual limit (0 if current or never tested).
    function overdueBy(address member) public view returns (uint64) {
        IqResults[] storage h = iqHistory[member];
        if (h.length == 0) return 0;
        uint256 elapsed = block.timestamp - h[h.length - 1].date;
        if (elapsed <= STALENESS_LIMIT) return 0;
        return uint64(elapsed - STALENESS_LIMIT);
    }

    // Unweighted mean over the full history. Reverts if never tested.
    function averageIq(address member) public view returns (uint16) {
        IqResults[] storage h = iqHistory[member];
        require(h.length > 0, "no test on record");
        uint256 sum;
        for (uint256 i = 0; i < h.length; i++) {
            sum += h[i].score;
        }
        return uint16(sum / h.length);
    }

    // getIq(): the agreed shorthand. Currently aliases the latest score;
    // swap the body for averageIq(member) if policy settles on the mean.
    function getIq(address member) external view returns (uint16) {
        return latestIq(member);
    }

    // Full history for off-chain display; free to read on a zero-gas network.
    function history(address member) external view returns (IqResults[] memory) {
        return iqHistory[member];
    }
}

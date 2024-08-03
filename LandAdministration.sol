// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;                             // versio of the solidity compiler im using..range mentioned here

interface LandAdministrationInterface
{

    function ownersOf(uint256 tokenId) external view returns(address[] memory);

    function shareOf(uint256 tokenId,address owner) external view returns(uint16);

    function transferFrom(address from, address to,uint256 tokenId,uint16 share) external payable;

    function isTransferable(uint256 tokenId) external view returns(bool);

    function setTransferable(uint256 tokenId, bool value) external payable;

    //event Transfer(address from,address to,uint256 tokenId,uint16 share);
    
}

contract LandAdministration  is LandAdministrationInterface
{
    address master;
    address govt;
    uint256 private count=1;


    mapping(uint256 => address[]) private realEstateOwners;
    mapping(uint256 => mapping(address => uint16)) private realEstateOwnersShare;
    mapping(uint256 => bool) private transferable;
    mapping(uint256 => bool) private token_posted;

    mapping(uint256 => land) private landDetails;
    mapping(address => person) private  personDetails;
    address[] private trustedMembers;
    land[] private lands;


    /////////////////////////////////////////////////////////////////////////////////////////// structures 
    struct person
    {
        address person;
        string name;
        uint256 aadharNumber;
        uint256 phoneNumber;
        string email;
    }
    struct land
    {
        string district;
        string taluk;
        string village;
        uint256 pattaNumber;
    }

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    constructor()
    {
        master=msg.sender;
    }

/////////////////////////////////////////////////////////////////////////////////// //////////////////////////////////////Modifiers for authorization
    modifier isMaster() 
    {
        require(msg.sender==master,"sorry only the master can call this function");
        _;
    }
    modifier isGovt()
    {
        require(msg.sender==govt,"sorry only the govt can call this function");
        _;
    }

    function isTrustedMember(address who) private view returns(bool)
    {
        for(uint i=0;i<trustedMembers.length;i++)
        {
            if(trustedMembers[i]==who)
            {
                return true;
            }
        }
        return false;
    }
 /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////Basic functions
    function addGovt(address government) public isMaster
    {
        govt=government;
    }

    function ownersOf(uint256 tokenId) override public view returns(address[] memory)
    {
        return realEstateOwners[tokenId];
    }

    function shareOf(uint256 tokenId,address owner) override public view returns(uint16)
    {
        return realEstateOwnersShare[tokenId][owner];
    }

    function isOwner(uint256 tokenId,address owner) private view returns(bool)
    {
        address[] memory allOwners=realEstateOwners[tokenId];
        for(uint i=0;i<allOwners.length;i++)
        {
            if(allOwners[i]==owner)
            {
                return true;
            }
        }
        return false;
    }

    function isTransferable(uint256 tokenId) override public view returns(bool)
    {
        return transferable[tokenId];
    }

    function setTransferable(uint256 tokenId,bool value) isMaster public payable 
    {
        transferable[tokenId]=value;
    }

    function getIndexOfOwner(uint256 tokenId,address owner) private view returns(int)
    {
        for(uint i=0;i<realEstateOwners[tokenId].length;i++)
        {
            if(owner==realEstateOwners[tokenId][i])
            {
                return int(i);
            }
        }
        return -1;
    }
//////////////////////////////////////////////////////////////////////////////////////////////////// view functions

    function trustedMemberDetails(address who) isMaster public view returns(person memory)
    {
        return personDetails[who];
    }

    function registeredLandDetails(uint256 tokenId) public view returns(land memory)
    {
        if(!(msg.sender== master || isOwner(tokenId,msg.sender)))
        {
            revert notOwnerOrMaster({ tokenId:tokenId, from:msg.sender});
        }
        return landDetails[tokenId];
    }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function addToRealEstateOwner(uint256 tokenId,address owner) private
    {
        if(!isOwner(tokenId,owner))
        {
            realEstateOwners[tokenId].push(owner);
        }  
    }
    function removeFromOwnersList(uint256 tokenId,address from) private 
    {
        if(shareOf(tokenId,from)==0)
        {
            int i=getIndexOfOwner(tokenId,from);
            if(i!=1)
            {
                delete realEstateOwners[tokenId][uint(i)];
            }
        }
    }
    function check_for_same(land memory land1,land memory land2) internal pure returns(bool)
    {
        bool value=keccak256(abi.encodePacked(land1.district)) == keccak256(abi.encodePacked(land2.district)) && 
        keccak256(abi.encodePacked(land1.taluk)) == keccak256(abi.encodePacked(land2.taluk)) &&
        keccak256(abi.encodePacked(land1.village)) == keccak256(abi.encodePacked(land2.village))&&
        keccak256(abi.encodePacked(land1.pattaNumber)) == keccak256(abi.encodePacked(land2.pattaNumber));
        return(value);
    }
    function doesLandExists(land memory a) private view returns(bool)
    {
        for(uint i=0;i<lands.length;i++)
        {
            if(check_for_same(a, lands[i])==true)
            {
                return true;
            }
        }
        return false;
    }
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function mint(address to,string memory district,string memory taluk,string memory village,uint256 pattaNumber,uint16 share) public isMaster
    {
        if(isTrustedMember(to)==false)
        {
            revert notTrustedMember({who:to});
        }
        land memory l=land(district,taluk,village,pattaNumber);

        require(doesLandExists(l)==false,"sorry the land already exists");

        lands.push(l);
        landDetails[count]=l;
        transferable[count]=true;
        realEstateOwners[count].push(to);
        realEstateOwnersShare[count][to]=share;
        token_posted[count]=false;
        count=count+1;
    }
    function addtrustedmembers(address personi,string memory name,uint256 aadharNumber,uint256 phoneNumber,string memory email) public isMaster
    {
        person memory p=person(personi,name,aadharNumber,phoneNumber,email);
        trustedMembers.push(personi);
        personDetails[personi]=p;
    }

    function transferFrom(address from,address to,uint256 tokenId,uint16 share) override public payable
    {
        if(!transferable[tokenId])
        {
            revert nonTransferable({ tokenId: tokenId});
        }

        if(!(msg.sender== master || isOwner(tokenId,from)))
        {
            revert notOwnerOrMaster({ tokenId:tokenId, from:from});
        }

        if(shareOf(tokenId,from)<share)
        {
            revert notOwningBigEnoughShare({
                tokenId:tokenId,
                from:from,
                owningShare:shareOf(tokenId,from),
                transferingShare:share
            });
        }

        realEstateOwnersShare[tokenId][from]-=share;
        realEstateOwnersShare[tokenId][to]+=share;
        addToRealEstateOwner(tokenId,to);
        removeFromOwnersList(tokenId, from);
    }
    ////////////////////////////////////////////////////////////////////////// errors here /////////////////////
    error nonTransferable(uint256 tokenId);
    error notOwnerOrMaster(uint256 tokenId,address from);
    error notOwningBigEnoughShare(uint256 tokenId,address from,uint16 owningShare,uint16 transferingShare);
    error notTrustedMember(address who);

    //////////////////////////////////////////////////////////////////////////// now we are creating a posting platform
    // this part of coding is our own creation
    mapping(uint256 => uint256[]) public token_money;
    uint256[] tokens_for_sale;
    mapping(uint256 => address) private who_posted;



    function postLand(uint256 tokenId,uint16 amount,uint256 share) public 
    {
        if(token_posted[tokenId]==true)
        {
            revert nonTransferable({ tokenId: tokenId});
        }
        if(!transferable[tokenId])
        {
            revert nonTransferable({ tokenId: tokenId});
        }
        if(!(isOwner(tokenId,msg.sender)))
        {
            revert notOwnerOrMaster({ tokenId:tokenId, from:msg.sender});
        }
        if(shareOf(tokenId,msg.sender)<share)
        {
            revert notOwningBigEnoughShare({
                tokenId:tokenId,
                from:msg.sender,
                owningShare:shareOf(tokenId,msg.sender),
                transferingShare:uint16(share)
            });
        }
        token_money[tokenId]=[amount,share];
        token_posted[tokenId]=true;
    } 
    function transferFromInside(address from,address to,uint256 tokenId,uint16 share) private 
    {
        realEstateOwnersShare[tokenId][from]-=share;
        realEstateOwnersShare[tokenId][to]+=share;
        addToRealEstateOwner(tokenId,to);
        removeFromOwnersList(tokenId, from);
    }

    function buyLand(uint256 tokenId) public payable 
    {
        uint256 amount=token_money[tokenId][0];
        if(isTrustedMember(msg.sender)==false)
        {
            revert notTrustedMember({who:msg.sender});
        }
        address payable owner=payable(ownersOf(tokenId)[0]);
        require(msg.value>amount,"sorry enter more money to buy");
        owner.transfer(msg.value);
        uint16 share=uint16(token_money[tokenId][1]);
        transferFromInside(owner,msg.sender,tokenId,share);
        token_posted[tokenId]=false;
    }

}

